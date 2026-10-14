import { afterAll, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const VALIDATOR = join(import.meta.dir, "validate.ts");
const TEMP_ROOT = mkdtempSync(join(tmpdir(), "validate-test-"));

const WELL_FORMED = `---
name: demo
description: Review a change for problems. Use when reviewing a diff.
---

# Demo

One line of intent.

## Red flags

- A failure mode
`;

function skill(frontmatter: string, body: string): string {
  return `---\n${frontmatter}\n---\n\n# Demo\n\n${body}\n`;
}

const REVIEW = "name: demo\ndescription: Review a change. Use when reviewing.";
const RED_FLAGS = "## Red flags\n\n- x";

type Run = { readonly code: number; readonly output: string };

function fixture(): string {
  const root = mkdtempSync(join(TEMP_ROOT, "case-"));
  mkdirSync(join(root, "skills", "workflow", "demo"), { recursive: true });
  return root;
}

function write(root: string, path: string, text: string): void {
  const full = join(root, path);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, text);
}

function validate(...args: readonly string[]): Run {
  const result = Bun.spawnSync([process.execPath, VALIDATOR, ...args]);
  return {
    code: result.exitCode,
    output: `${result.stdout.toString()}${result.stderr.toString()}`,
  };
}

afterAll(() => rmSync(TEMP_ROOT, { recursive: true, force: true }));

describe("validate", () => {
  test("passes a well-formed skill", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
    const run = validate(root);
    expect(run.code).toBe(0);
    expect(run.output).toContain("OK: skill validation passed");
  });

  test("passes Claude as a tool name, not a model", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `Read the repo's CLAUDE.md before running Claude Code.\n\n${RED_FLAGS}`),
    );
    expect(validate(root).code).toBe(0);
  });

  test("fails a skill directory with no SKILL.md", () => {
    const run = validate(fixture());
    expect(run.code).toBe(1);
    expect(run.output).toContain("missing SKILL.md");
  });

  test("fails a name that does not match the directory", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill("name: other\ndescription: Review a change. Use when reviewing.", RED_FLAGS),
    );
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("must match directory");
  });

  test("fails a skill with no Red flags section", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, "No red flags here."));
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("missing '## Red flags'");
  });

  test("rejects an Anti-patterns heading", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, "## Anti-patterns\n\n- x"));
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("use '## Red flags' instead");
  });

  test("fails a description that does not start with an imperative verb", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill("name: demo\ndescription: Quickly patches things. Use when needed.", RED_FLAGS),
    );
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("imperative verb");
  });

  describe("links and references", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `See [the checklist](references/checklist.md).\n\n${RED_FLAGS}`),
    );

    test("fails a link to a file that does not exist", () => {
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "link 'references/checklist.md' in demo must name a file inside the skill's own directory",
      );
    });

    test("passes once the linked file exists", () => {
      write(root, "skills/workflow/demo/references/checklist.md", "# Checklist\n");
      expect(validate(root).code).toBe(0);
    });

    test("fails a model name in a reference file", () => {
      write(root, "skills/workflow/demo/references/checklist.md", "# Checklist\n\nRun it on GPT-4.\n");
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toMatch(/named model in (\S*\/)?skills\/workflow\/demo\/references\/checklist\.md/);
      expect(run.output).toContain("3:Run it on GPT-4.");
    });

    test("passes a reference that links up to SKILL.md", () => {
      write(
        root,
        "skills/workflow/demo/references/checklist.md",
        "# Checklist\n\nSee [the rules](../SKILL.md#red-flags).\n",
      );
      expect(validate(root).code).toBe(0);
    });

    test("resolves a reference's link from the reference, not the skill root", () => {
      write(
        root,
        "skills/workflow/demo/references/checklist.md",
        "# Checklist\n\nSee [the checklist](references/checklist.md).\n",
      );
      expect(validate(root).code).toBe(1);
    });
  });

  test("fails a link to an existing file outside the skill's directory", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `See [plan](../plan/SKILL.md).\n\n${RED_FLAGS}`),
    );
    write(root, "skills/workflow/plan/SKILL.md", skill(REVIEW.replace("demo", "plan"), RED_FLAGS));
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain(
      "link '../plan/SKILL.md' in demo must name a file inside the skill's own directory",
    );
  });

  test("skips web, mail and in-page links", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(
        REVIEW,
        `See [a](https://example.com/x), [b](mailto:a@example.com) and [c](#red-flags).\n\n${RED_FLAGS}`,
      ),
    );
    expect(validate(root).code).toBe(0);
  });

  test("reads a link only within one line", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `Write \`](\` to open a link target.\n\nThen close it (once).\n\n${RED_FLAGS}`),
    );
    expect(validate(root).code).toBe(0);
  });

  test("fails a skill with no frontmatter", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", `# Demo\n\nNo frontmatter at all.\n\n${RED_FLAGS}\n`);
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("missing YAML frontmatter");
  });

  test("fails a model name in README.md", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
    write(root, "README.md", "# Skills\n\nPick Opus for planning.\n");
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("named model in README.md");
    expect(run.output).toContain("3:Pick Opus for planning.");
  });

  test("names the fix once for every skill that breaks the same rule", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, "No red flags here."));
    write(
      root,
      "skills/workflow/other/SKILL.md",
      skill(REVIEW.replace("demo", "other"), "No red flags here."),
    );
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("missing '## Red flags' section in skills/workflow/demo/SKILL.md");
    expect(run.output).toContain("missing '## Red flags' section in skills/workflow/other/SKILL.md");
    expect(run.output.split("to resolve: end SKILL.md with a '## Red flags' section")).toHaveLength(2);
  });

  test("reports a frontmatter line the parser cannot read, with its fix", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", skill(`${REVIEW}\ntags:\n  - git`, RED_FLAGS));
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("skills/workflow/demo/SKILL.md: frontmatter unsupported line in:   - git");
    expect(run.output).toContain("to resolve: rewrite that line in skills/workflow/demo/SKILL.md");
  });

  describe("skill kinds", () => {
    const EXPERTISE = "name: rules\ndescription: Review a change. Use when reviewing.";

    function kinds(rulesBody: string): string {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
      write(root, "skills/expertise/rules/SKILL.md", skill(EXPERTISE, rulesBody));
      return root;
    }

    test("fails a skill outside the workflow and expertise folders", () => {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
      write(root, "skills/loose/SKILL.md", skill(REVIEW.replace("demo", "loose"), RED_FLAGS));
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain("skills/loose is outside skills/workflow/ and skills/expertise/");
    });

    test("fails a skill name in both folders", () => {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
      write(root, "skills/expertise/demo/SKILL.md", WELL_FORMED);
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "skill demo sits in more than one of skills/workflow/ and skills/expertise/",
      );
    });

    test("fails an expertise skill that routes to a workflow skill", () => {
      const run = validate(kinds(`Carry the fix out with \`demo\`.\n\n${RED_FLAGS}`));
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "expertise skill names a workflow skill outside ## See also in skills/expertise/rules/SKILL.md",
      );
      expect(run.output).toContain("8:Carry the fix out with `demo`.");
    });

    test("fails an expertise reference that routes to a workflow skill", () => {
      const root = kinds(RED_FLAGS);
      write(root, "skills/expertise/rules/references/more.md", "# More\n\nLoad `demo` next.\n");
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain("outside ## See also in skills/expertise/rules/references/more.md");
    });

    test("passes an expertise skill that names a workflow skill under See also", () => {
      expect(validate(kinds(`## See also\n\n- \`demo\` for the steps\n\n${RED_FLAGS}`)).code).toBe(0);
    });

    test("passes a span that only starts with a workflow skill's name", () => {
      expect(validate(kinds(`Run \`demo log\` and \`demo-x\`.\n\n${RED_FLAGS}`)).code).toBe(0);
    });

    test("passes an expertise skill that names another expertise skill", () => {
      const root = kinds(`Use \`rules\` and \`other\` here.\n\n${RED_FLAGS}`);
      expect(validate(root).code).toBe(0);
    });

    test("passes a workflow skill that names a workflow skill", () => {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, `Then load \`plan\`.\n\n${RED_FLAGS}`));
      write(root, "skills/workflow/plan/SKILL.md", skill(REVIEW.replace("demo", "plan"), RED_FLAGS));
      expect(validate(root).code).toBe(0);
    });
  });

  describe("plugin manifest", () => {
    function withManifest(manifest: object): Run {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
      write(root, ".claude-plugin/plugin.json", JSON.stringify(manifest));
      return validate(root);
    }

    test("passes a manifest that lists both skill folders", () => {
      expect(withManifest({ name: "p", skills: ["./skills/workflow", "./skills/expertise"] }).code).toBe(0);
    });

    test("fails a manifest that lists no skill folders", () => {
      const run = withManifest({ name: "p" });
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        ".claude-plugin/plugin.json lists skills [], not [./skills/workflow, ./skills/expertise]",
      );
    });

    test("fails a manifest that misses a skill folder", () => {
      const run = withManifest({ name: "p", skills: ["./skills/workflow"] });
      expect(run.code).toBe(1);
      expect(run.output).toContain("lists skills [./skills/workflow], not");
    });
  });

  test("refuses a root with no skills directory", () => {
    const root = mkdtempSync(join(TEMP_ROOT, "empty-"));
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain(`no skills/ directory in ${root}`);
    expect(run.output).not.toContain("OK: skill validation passed");
  });

  test("refuses more than one argument as a usage error", () => {
    const run = validate(fixture(), "extra");
    expect(run.code).toBe(2);
    expect(run.output).toContain("usage: bun scripts/validate.ts [root]");
  });
});
