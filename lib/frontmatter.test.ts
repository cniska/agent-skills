import { describe, expect, test } from "bun:test";

import { CodedError } from "./coded-error";
import { frontmatter } from "./frontmatter";

describe("frontmatter", () => {
  test("reads scalars, inline lists, inline maps and nested maps", () => {
    const text = [
      "---",
      "type: regex",
      "pattern: 'it''s'",
      "tags: [git, review]",
      "before: { tool: Bash, input_match: rebase }",
      "target:",
      "  source: file",
      "  path: out.md",
      "---",
    ].join("\n");
    expect(frontmatter(text, "f.md")).toEqual({
      type: "regex",
      pattern: "it's",
      tags: ["git", "review"],
      before: { tool: "Bash", input_match: "rebase" },
      target: { source: "file", path: "out.md" },
    });
  });

  test("joins folded and literal blocks", () => {
    expect(frontmatter("---\na: >\n  one\n  two\nb: |\n  one\n  two\n---", "f.md")).toEqual({
      a: "one two",
      b: "one\ntwo",
    });
  });

  test("refuses a block list, so tags stay inline", () => {
    expect(() => frontmatter("---\ntags:\n  - git\n---", "f.md")).toThrow(CodedError);
  });

  test("refuses an inline item it cannot read plainly", () => {
    expect(() => frontmatter('---\ntags: [git, "a,b"]\n---', "f.md")).toThrow(CodedError);
  });

  test("reads text with no frontmatter as empty", () => {
    expect(frontmatter("just a prompt", "f.md")).toEqual({});
  });
});
