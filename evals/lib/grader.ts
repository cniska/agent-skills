import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import { z } from "zod";
import { CodedError } from "../../lib/coded-error";
import { type Frontmatter, readFrontmatter } from "../../lib/frontmatter";
import { isMissingFile } from "../../lib/read-file";
import { unreachable } from "./assert";
import type { ToolCall, Trace } from "./trace";

const COUNT_MATCH = /^count:(\d+)$/;

const MatchSpec = z.union([
  z.literal("contains").transform(() => ({ kind: "contains" as const })),
  z.literal("not_contains").transform(() => ({ kind: "absent" as const })),
  z
    .string()
    .regex(COUNT_MATCH, 'must be "contains", "not_contains" or "count:N"')
    .transform((value) => ({ kind: "count" as const, count: Number(COUNT_MATCH.exec(value)?.[1]) })),
]);

const Target = z.union([
  z.enum(["last_message", "trace", "files", "mock_calls"]),
  z.strictObject({ source: z.literal("file"), path: z.string() }),
]);

const ToolSpec = z.union([
  z.string().transform((tool) => ({ tool, input_match: null })),
  z.strictObject({ tool: z.string(), input_match: z.string().nullable().default(null) }),
]);

const Count = z.coerce.number().int().nonnegative();

const common = {
  weight: z.coerce.number().positive().optional(),
  arm: z.enum(["with-only", "both"]).optional(),
};

const GraderSpec = z.discriminatedUnion("type", [
  z.strictObject({
    type: z.literal("regex"),
    ...common,
    pattern: z.string(),
    flags: z.string().default(""),
    match: MatchSpec.default({ kind: "contains" }),
    target: Target.default("last_message"),
  }),
  z.strictObject({
    type: z.literal("tool_used"),
    ...common,
    tool: z.string(),
    input_match: z.string().nullable().default(null),
    min: Count.default(1),
    max: Count.nullable().default(null),
  }),
  z.strictObject({ type: z.literal("tool_order"), ...common, before: ToolSpec, after: ToolSpec }),
  z.looseObject({ type: z.literal("file_exists") }),
  z.looseObject({ type: z.literal("llm") }),
  z.looseObject({ type: z.literal("baseline") }),
]);

type ToolMatcher = { readonly tool: string; readonly input: RegExp | null };

type Match =
  | { readonly kind: "contains"; readonly regex: RegExp }
  | { readonly kind: "absent"; readonly regex: RegExp }
  | { readonly kind: "count"; readonly count: number; readonly regex: RegExp };

export type Grader = { readonly name: string } & (
  | { readonly type: "regex"; readonly target: z.infer<typeof Target>; readonly match: Match }
  | {
      readonly type: "tool_used";
      readonly call: ToolMatcher;
      readonly min: number;
      readonly max: number | null;
    }
  | { readonly type: "tool_order"; readonly before: ToolMatcher; readonly after: ToolMatcher }
  | { readonly type: "file_exists" | "llm" | "baseline" }
);

function compile(path: string, pattern: string, flags: string): RegExp {
  try {
    return new RegExp(pattern, flags);
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    throw new CodedError("grader_invalid", {
      path,
      problem: `pattern ${JSON.stringify(pattern)}: ${error.message}`,
    });
  }
}

function toolMatcher(path: string, tool: string, inputMatch: string | null): ToolMatcher {
  return { tool, input: inputMatch === null ? null : compile(path, inputMatch, "") };
}

function regexMatch(path: string, pattern: string, flags: string, spec: z.infer<typeof MatchSpec>): Match {
  switch (spec.kind) {
    case "contains":
    case "absent":
      return { kind: spec.kind, regex: compile(path, pattern, flags.replace("g", "")) };
    case "count":
      return {
        kind: "count",
        count: spec.count,
        regex: compile(path, pattern, flags.includes("g") ? flags : `${flags}g`),
      };
    default:
      return unreachable(spec);
  }
}

export function parseGrader(path: string, frontmatterSpec: Frontmatter): Grader {
  const name = basename(path, ".md");
  const parsed = GraderSpec.safeParse(frontmatterSpec);
  if (!parsed.success)
    throw new CodedError("grader_invalid", { path, problem: z.prettifyError(parsed.error) });
  const spec = parsed.data;
  switch (spec.type) {
    case "regex":
      return {
        name,
        type: "regex",
        target: spec.target,
        match: regexMatch(path, spec.pattern, spec.flags, spec.match),
      };
    case "tool_used":
      return {
        name,
        type: "tool_used",
        call: toolMatcher(path, spec.tool, spec.input_match),
        min: spec.min,
        max: spec.max,
      };
    case "tool_order":
      return {
        name,
        type: "tool_order",
        before: toolMatcher(path, spec.before.tool, spec.before.input_match),
        after: toolMatcher(path, spec.after.tool, spec.after.input_match),
      };
    case "file_exists":
    case "llm":
    case "baseline":
      return { name, type: spec.type };
    default:
      return unreachable(spec);
  }
}

export function loadGraders(caseDir: string): Grader[] {
  const graderDir = join(caseDir, "graders");
  if (!existsSync(graderDir)) throw new CodedError("graders_missing", { dir: caseDir });
  return readdirSync(graderDir)
    .filter((file) => file.endsWith(".md"))
    .sort()
    .map((file) => join(graderDir, file))
    .map((path) => parseGrader(path, readFrontmatter(path)));
}

function fileText(workspace: string | null, path: string): string | null {
  if (workspace === null) return null;
  try {
    return readFileSync(join(workspace, path), "utf8");
  } catch (error) {
    if (isMissingFile(error)) return null;
    throw error;
  }
}

function targetText(target: z.infer<typeof Target>, trace: Trace, workspace: string | null): string | null {
  if (typeof target === "object") return fileText(workspace, target.path);
  switch (target) {
    case "last_message":
      return trace.lastMessage;
    case "trace":
      return trace.text;
    case "files":
    case "mock_calls":
      return null;
    default:
      return unreachable(target);
  }
}

function matches(call: ToolCall, matcher: ToolMatcher): boolean {
  return call.name === matcher.tool && (matcher.input === null || matcher.input.test(call.input));
}

function firstCallIndex(trace: Trace, matcher: ToolMatcher): number {
  return trace.toolCalls.findIndex((call) => matches(call, matcher));
}

function regexVerdict(match: Match, text: string): boolean {
  switch (match.kind) {
    case "contains":
      return match.regex.test(text);
    case "absent":
      return !match.regex.test(text);
    case "count":
      return (text.match(match.regex) ?? []).length === match.count;
    default:
      return unreachable(match);
  }
}

export function grade(grader: Grader, trace: Trace, workspace: string | null): boolean | null {
  switch (grader.type) {
    case "regex": {
      const text = targetText(grader.target, trace, workspace);
      return text === null ? null : regexVerdict(grader.match, text);
    }
    case "tool_used": {
      const count = trace.toolCalls.filter((call) => matches(call, grader.call)).length;
      return count >= grader.min && (grader.max === null || count <= grader.max);
    }
    case "tool_order": {
      const before = firstCallIndex(trace, grader.before);
      const after = firstCallIndex(trace, grader.after);
      return before >= 0 && after >= 0 && before < after;
    }
    case "file_exists":
    case "llm":
    case "baseline":
      return null;
    default:
      return unreachable(grader);
  }
}
