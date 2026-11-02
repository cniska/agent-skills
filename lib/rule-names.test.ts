import { afterAll, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

import { type RuleSource, ruleNames } from "./rule-names";

const TEMP_ROOT = mkdtempSync(join(tmpdir(), "rule-names-test-"));

afterAll(() => rmSync(TEMP_ROOT, { recursive: true, force: true }));

function root(files: Record<string, string>): string {
  const dir = mkdtempSync(join(TEMP_ROOT, "case-"));
  for (const [path, text] of Object.entries(files)) {
    mkdirSync(dirname(join(dir, path)), { recursive: true });
    writeFileSync(join(dir, path), text);
  }
  return dir;
}

const REVIEW = [
  "# Review",
  "## Scope",
  "### 1. Logic",
  "### 2. Edge cases",
  "```",
  "### Fenced",
  "```",
  "## Output",
  "### Not a rule",
].join("\n");

describe("ruleNames", () => {
  test("takes the headings under a parent, dropping their numbers, and skips fenced text", () => {
    const sources: RuleSource[] = [{ path: "a.md", pick: { kind: "headings", level: 3 }, under: ["Scope"] }];
    expect(ruleNames(root({ "a.md": REVIEW }), sources)).toEqual({
      names: [
        { name: "Edge cases", sources: ["a.md"] },
        { name: "Logic", sources: ["a.md"] },
      ],
      problems: [],
    });
  });

  test("takes bold leads without their closing mark, and a title from each file of a directory", () => {
    const sources: RuleSource[] = [
      { path: "b.md", pick: { kind: "bold_leads" } },
      { path: "refs", pick: { kind: "title" }, except: ["Skip me"] },
    ];
    const dir = root({
      "b.md":
        "# B\n\n- **Data flows one way.** Values go down.\n- **The prompt is ordered:** stable first.\n  - **Nested** no\n",
      "refs/one.md": "# Fix the cause\n",
      "refs/two.md": "# Skip me\n",
    });
    expect(ruleNames(dir, sources).names.map(({ name }) => name)).toEqual([
      "Data flows one way",
      "Fix the cause",
      "The prompt is ordered",
    ]);
  });

  test("merges one name from two sources", () => {
    const sources: RuleSource[] = [
      { path: "a.md", pick: { kind: "headings", level: 3 }, under: ["Scope"] },
      { path: "c.md", pick: { kind: "headings", level: 2 } },
    ];
    const dir = root({ "a.md": REVIEW, "c.md": "# C\n## Edge cases\n" });
    expect(ruleNames(dir, sources).names).toContainEqual({ name: "Edge cases", sources: ["a.md", "c.md"] });
  });

  test("names each parent or excluded heading that is gone, and a source that gives nothing", () => {
    const sources: RuleSource[] = [
      { path: "a.md", pick: { kind: "headings", level: 3 }, under: ["Rules"], except: ["Proof"] },
      { path: "gone.md", pick: { kind: "title" } },
    ];
    expect(ruleNames(root({ "a.md": REVIEW }), sources).problems).toEqual([
      'a.md: no heading "Rules" for the rule names to read',
      'a.md: no heading "Proof" for the rule names to read',
      "a.md: gives no rule name",
      "gone.md: no rule source at this path",
    ]);
  });
});
