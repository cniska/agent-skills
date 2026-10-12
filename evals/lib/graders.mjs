import { readFileSync, readdirSync } from "node:fs";
import { basename, join } from "node:path";
import { frontmatter } from "./frontmatter.mjs";

const MODEL_ONLY_TYPES = new Set(["judge"]);

function traceMessages(trace) {
  return trace
    .split("\n")
    .filter((line) => line.trim())
    .map((line) => JSON.parse(line));
}

function contentBlocks(message) {
  const content = message?.message?.content;
  return Array.isArray(content) ? content : [];
}

function lastMessage(trace) {
  let last = "";
  for (const message of traceMessages(trace)) {
    if (message?.type !== "assistant") continue;
    const text = contentBlocks(message)
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("\n");
    if (text) last = text;
  }
  return last;
}

function targetText(g, trace, workspace) {
  const target = g.target ?? "last_message";
  if (target === "trace") return trace;
  if (target === "last_message") return lastMessage(trace);
  if (typeof target !== "object" || target.source !== "file") throw new Error(`grader ${g.name}: unknown target ${JSON.stringify(target)}`);
  if (!workspace) return null;
  try {
    return readFileSync(join(workspace, target.path), "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function toolCalls(trace) {
  return traceMessages(trace)
    .flatMap(contentBlocks)
    .filter((block) => block.type === "tool_use")
    .map((block) => ({ name: block.name, input: JSON.stringify(block.input) }));
}

function firstCallIndex(trace, spec) {
  const { tool, input_match } = typeof spec === "string" ? { tool: spec } : spec ?? {};
  const pattern = input_match ? new RegExp(input_match) : null;
  return toolCalls(trace).findIndex((c) => c.name === tool && (!pattern || pattern.test(c.input)));
}

const GRADE_BY_TYPE = {
  regex(g, trace, workspace) {
    const text = targetText(g, trace, workspace);
    if (text === null) return null;
    const hit = new RegExp(g.pattern, g.flags ?? "").test(text);
    return g.match === "not_contains" ? !hit : hit;
  },
  tool_order(g, trace) {
    const before = firstCallIndex(trace, g.before);
    const after = firstCallIndex(trace, g.after);
    return before >= 0 && after >= 0 && before < after;
  },
  tool_used(g, trace) {
    const pattern = g.input_match ? new RegExp(g.input_match) : null;
    const count = toolCalls(trace).filter((c) => c.name === g.tool && (!pattern || pattern.test(c.input))).length;
    return count >= Number(g.min ?? 1) && (g.max === undefined || count <= Number(g.max));
  },
};

export function grade(g, trace, workspace = null) {
  if (MODEL_ONLY_TYPES.has(g.type)) return null;
  const gradeType = GRADE_BY_TYPE[g.type];
  if (!gradeType) throw new Error(`grader ${g.name}: unknown type ${g.type}`);
  return gradeType(g, trace, workspace);
}

export function loadGraders(caseDir) {
  const graderDir = join(caseDir, "graders");
  return readdirSync(graderDir)
    .filter((f) => f.endsWith(".md"))
    .map((f) => ({ name: basename(f, ".md"), ...frontmatter(readFileSync(join(graderDir, f), "utf8")) }));
}
