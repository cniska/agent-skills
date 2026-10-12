import { describe, expect, test } from "bun:test";
import { CodedError } from "./coded-error";
import type { Frontmatter } from "./frontmatter";
import { grade, parseGrader } from "./grader";
import { parseTrace } from "./trace";

const TRACE = parseTrace(
  [
    JSON.stringify({ type: "user", message: { content: "rebase my branch" } }),
    JSON.stringify({
      type: "assistant",
      message: {
        content: [
          { type: "text", text: "Loading the skill." },
          { type: "tool_use", name: "Skill", input: { skill: "cniska-skills:git" } },
          { type: "tool_use", name: "Bash", input: { command: "git rebase main" } },
          { type: "tool_use", name: "Bash", input: { command: "git push --force-with-lease" } },
        ],
      },
    }),
    JSON.stringify({ type: "assistant", message: { content: [{ type: "text", text: "Rebased on main." }] } }),
  ].join("\n"),
  "trace.jsonl",
);

function verdict(spec: Frontmatter): boolean | null {
  return grade(parseGrader("graders/g.md", spec), TRACE, null);
}

function refusal(spec: Frontmatter): unknown {
  try {
    parseGrader("graders/g.md", spec);
  } catch (error) {
    return error;
  }
  return null;
}

describe("graders checked only by a model run", () => {
  test.each(["llm", "baseline", "file_exists"])("%s loads and is not checked offline", (type) => {
    expect(verdict({ type, criteria: "PASS when it rebased", path: "out/*.md" })).toBeNull();
  });

  test("an unknown type is refused at load with the grader named", () => {
    const error = refusal({ type: "judge" });
    expect(error).toBeInstanceOf(CodedError);
    expect(error instanceof CodedError && error.code).toBe("grader-invalid");
    expect(error instanceof CodedError && error.message).toStartWith("graders/g.md:");
  });
});

describe("regex", () => {
  test("reads the final message by default", () => {
    expect(verdict({ type: "regex", pattern: "Rebased" })).toBe(true);
    expect(verdict({ type: "regex", pattern: "Merged" })).toBe(false);
  });

  test("not_contains passes only when the pattern is absent", () => {
    expect(verdict({ type: "regex", pattern: "Merged", match: "not_contains" })).toBe(true);
    expect(verdict({ type: "regex", pattern: "Rebased", match: "not_contains" })).toBe(false);
  });

  test("count:N passes only on exactly N matches", () => {
    expect(verdict({ type: "regex", pattern: "git ", target: "trace", match: "count:2" })).toBe(true);
    expect(verdict({ type: "regex", pattern: "git ", target: "trace", match: "count:1" })).toBe(false);
  });

  test("count:0 passes only when the pattern never matches", () => {
    expect(verdict({ type: "regex", pattern: "merge", target: "trace", match: "count:0" })).toBe(true);
    expect(verdict({ type: "regex", pattern: "rebase", target: "trace", match: "count:0" })).toBe(false);
  });

  test("a g flag does not carry state from one check to the next", () => {
    const grader = parseGrader("graders/g.md", { type: "regex", pattern: "Rebased", flags: "g" });
    expect(grade(grader, TRACE, null)).toBe(true);
    expect(grade(grader, TRACE, null)).toBe(true);
  });

  test("a target only a model run can see is not checked offline", () => {
    expect(verdict({ type: "regex", pattern: "x", target: "files" })).toBeNull();
    expect(verdict({ type: "regex", pattern: "x", target: "mock_calls" })).toBeNull();
  });

  test("a file target with no workspace is not checked", () => {
    expect(verdict({ type: "regex", pattern: "x", target: { source: "file", path: "a.md" } })).toBeNull();
  });

  test("a pattern that does not compile is refused at load", () => {
    expect(refusal({ type: "regex", pattern: "(" })).toBeInstanceOf(CodedError);
  });

  test("an unknown match is refused at load", () => {
    expect(refusal({ type: "regex", pattern: "x", match: "count:two" })).toBeInstanceOf(CodedError);
  });
});

describe("tool_used", () => {
  test("counts calls whose JSON input matches, between min and max", () => {
    expect(verdict({ type: "tool_used", tool: "Bash", input_match: "rebase" })).toBe(true);
    expect(verdict({ type: "tool_used", tool: "Bash", input_match: "merge" })).toBe(false);
    expect(verdict({ type: "tool_used", tool: "Bash", min: "0", max: "0" })).toBe(false);
    expect(verdict({ type: "tool_used", tool: "Edit", min: "0", max: "0" })).toBe(true);
  });

  test("an unknown key is refused at load", () => {
    expect(refusal({ type: "tool_used", tool: "Bash", input: "rebase" })).toBeInstanceOf(CodedError);
  });
});

describe("tool_order", () => {
  test("passes only when the first before call precedes the first after call", () => {
    expect(verdict({ type: "tool_order", before: "Skill", after: "Bash" })).toBe(true);
    expect(verdict({ type: "tool_order", before: "Bash", after: "Skill" })).toBe(false);
    expect(
      verdict({
        type: "tool_order",
        before: { tool: "Bash", input_match: "push" },
        after: { tool: "Bash", input_match: "rebase" },
      }),
    ).toBe(false);
  });

  test("fails when either tool was never called", () => {
    expect(verdict({ type: "tool_order", before: "Skill", after: "Edit" })).toBe(false);
  });
});
