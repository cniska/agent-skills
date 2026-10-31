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
`;

function skill(frontmatter: string, body: string): string {
  return `---\n${frontmatter}\n---\n\n# Demo\n\n${body}\n`;
}

const REVIEW = "name: demo\ndescription: Review a change. Use when reviewing.";
const BODY = "Body.";

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
      skill(REVIEW, `Read the repo's CLAUDE.md before running Claude Code.\n\n${BODY}`),
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
      skill("name: other\ndescription: Review a change. Use when reviewing.", BODY),
    );
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("must match directory");
  });

  test("fails a description that does not start with an imperative verb", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill("name: demo\ndescription: Quickly patches things. Use when needed.", BODY),
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
      skill(REVIEW, `See [the checklist](references/checklist.md).\n\n${BODY}`),
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
        "# Checklist\n\nSee [the rules](../SKILL.md#see-also).\n",
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
    write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, `See [plan](../plan/SKILL.md).\n\n${BODY}`));
    write(root, "skills/workflow/plan/SKILL.md", skill(REVIEW.replace("demo", "plan"), BODY));
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain(
      "link '../plan/SKILL.md' in demo must name a file inside the skill's own directory",
    );
  });

  describe("paths into another skill", () => {
    const OTHER = "name: other\ndescription: Review a change. Use when reviewing.";

    function withOther(demoBody: string): string {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, `${demoBody}\n\n${BODY}`));
      write(root, "skills/expertise/other/SKILL.md", skill(OTHER, BODY));
      write(root, "skills/expertise/other/references/x.md", "# X\n");
      write(root, "skills/expertise/other/references/y.md", "# Y\n");
      return root;
    }

    test("fails a backticked path in SKILL.md that exists only under another skill", () => {
      const run = validate(withOther("Read `references/x.md` beside it."));
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "skills/workflow/demo/SKILL.md names 'references/x.md', a path inside the other skill's directory",
      );
    });

    test("fails the same path in a reference file", () => {
      const root = withOther("One line.");
      write(root, "skills/workflow/demo/references/notes.md", "# Notes\n\nRead `references/x.md`.\n");
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "skills/workflow/demo/references/notes.md names 'references/x.md', a path inside the other skill's directory",
      );
    });

    test("fails a path through another skill's directory", () => {
      const run = validate(withOther("Read `skills/expertise/other/references/z.md`."));
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "names 'skills/expertise/other/references/z.md', a path inside the other skill's directory",
      );
    });

    test("names the skill a relative path climbs into, not a sibling it climbs out of", () => {
      const root = withOther("Read `../../expertise/other/references/x.md`.");
      write(root, "skills/workflow/alpha/SKILL.md", skill(REVIEW.replace("demo", "alpha"), BODY));
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "names '../../expertise/other/references/x.md', a path inside the other skill's directory",
      );
      expect(run.output).not.toContain("alpha skill's directory");
    });

    test("fails a reference file's relative path that climbs into another skill", () => {
      const root = withOther("One line.");
      write(
        root,
        "skills/workflow/demo/references/notes.md",
        "# Notes\n\nRead `../../../expertise/other/references/x.md`.\n",
      );
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "skills/workflow/demo/references/notes.md names '../../../expertise/other/references/x.md', a path inside the other skill's directory",
      );
    });

    test("passes the skill's own references/x.md", () => {
      const root = withOther("Read `references/x.md`.");
      write(root, "skills/workflow/demo/references/x.md", "# X\n");
      expect(validate(root).code).toBe(0);
    });

    test("passes a reference file naming SKILL.md", () => {
      const root = withOther("One line.");
      write(root, "skills/workflow/demo/references/notes.md", "# Notes\n\nSee `SKILL.md`.\n");
      expect(validate(root).code).toBe(0);
    });

    test("passes a reference file naming its own skill's references/y.md", () => {
      const root = withOther("One line.");
      write(root, "skills/workflow/demo/references/notes.md", "# Notes\n\nSee `references/y.md`.\n");
      write(root, "skills/workflow/demo/references/y.md", "# Y\n");
      expect(validate(root).code).toBe(0);
    });

    test("passes project paths no skill holds", () => {
      expect(validate(withOther("Read `AGENTS.md` and `docs/architecture.md` first.")).code).toBe(0);
    });
  });

  test("skips mail and in-page links", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `See [b](mailto:a@example.com) and [c](#see-also).\n\n${BODY}`),
    );
    expect(validate(root).code).toBe(0);
  });

  test("fails a web link that is not a tool link", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, `Per [a](https://example.com/x).\n\n${BODY}`));
    write(root, "skills/workflow/demo/references/notes.md", "# Notes\n\nSee [b](http://example.com/y).\n");
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("web link 'https://example.com/x' in demo is not a tool link");
    expect(run.output).toContain("web link 'http://example.com/y' in demo is not a tool link");
  });

  test("passes a web link on the tool allowlist", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `Cases follow the [eval docs](https://code.claude.com/docs/en/plugin-evals).\n\n${BODY}`),
    );
    expect(validate(root).code).toBe(0);
  });

  test("passes a URL outside link syntax", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `Fetch \`https://example.com/<path>.json\`.\n\n${BODY}`),
    );
    expect(validate(root).code).toBe(0);
  });

  test("reads a link only within one line", () => {
    const root = fixture();
    write(
      root,
      "skills/workflow/demo/SKILL.md",
      skill(REVIEW, `Write \`](\` to open a link target.\n\nThen close it (once).\n\n${BODY}`),
    );
    expect(validate(root).code).toBe(0);
  });

  test("fails a skill with no frontmatter", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", `# Demo\n\nNo frontmatter at all.\n\n${BODY}\n`);
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

  test("fails a model name in a doc under docs/", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
    write(root, "docs/conventions.md", "# Tiers\n\nRun Haiku for reads.\n");
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain("named model in docs/conventions.md");
    expect(run.output).toContain("3:Run Haiku for reads.");
  });

  test("names the fix once for every skill that breaks the same rule", () => {
    const root = fixture();
    const vague = "name: demo\ndescription: A change review. Use when reviewing.";
    write(root, "skills/workflow/demo/SKILL.md", skill(vague, "Body."));
    write(root, "skills/workflow/other/SKILL.md", skill(vague.replace("demo", "other"), "Body."));
    const run = validate(root);
    expect(run.code).toBe(1);
    expect(run.output).toContain(
      "description should start with an imperative verb in skills/workflow/demo/SKILL.md",
    );
    expect(run.output).toContain(
      "description should start with an imperative verb in skills/workflow/other/SKILL.md",
    );
    expect(run.output.split("to resolve: start the description with one of")).toHaveLength(2);
  });

  test("reports a frontmatter line the parser cannot read, with its fix", () => {
    const root = fixture();
    write(root, "skills/workflow/demo/SKILL.md", skill(`${REVIEW}\ntags:\n  - git`, BODY));
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
      write(root, "skills/loose/SKILL.md", skill(REVIEW.replace("demo", "loose"), BODY));
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
      const run = validate(kinds(`Carry the fix out with \`demo\`.\n\n${BODY}`));
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "expertise skill names a workflow skill outside ## See also in skills/expertise/rules/SKILL.md",
      );
      expect(run.output).toContain("8:Carry the fix out with `demo`.");
    });

    test("fails an expertise reference that routes to a workflow skill", () => {
      const root = kinds(BODY);
      write(root, "skills/expertise/rules/references/more.md", "# More\n\nLoad `demo` next.\n");
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain("outside ## See also in skills/expertise/rules/references/more.md");
    });

    test("passes an expertise skill that names a workflow skill under See also", () => {
      expect(validate(kinds(`## See also\n\n- \`demo\` for the steps\n\n${BODY}`)).code).toBe(0);
    });

    test("passes a span that only starts with a workflow skill's name", () => {
      expect(validate(kinds(`Run \`demo log\` and \`demo-x\`.\n\n${BODY}`)).code).toBe(0);
    });

    test("fails a See also name that is no skill in the repo", () => {
      const run = validate(kinds(`## See also\n\n- \`demo\` and \`ghost\` for the steps\n\n${BODY}`));
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "## See also names 'ghost', which is no skill in this repo, in skills/expertise/rules/SKILL.md",
      );
      expect(run.output).toContain("10:- `demo` and `ghost` for the steps");
      expect(run.output).not.toContain("names 'demo'");
    });

    test("fails a See also name in a reference file", () => {
      const root = kinds(BODY);
      write(root, "skills/expertise/rules/references/more.md", "# More\n\n## See also\n\n- `ghost`\n");
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "names 'ghost', which is no skill in this repo, in skills/expertise/rules/references/more.md",
      );
    });

    test("passes a See also link to a file in the skill and a name outside See also", () => {
      const root = kinds(
        `Run \`ghost\` first.\n\n## See also\n\n- [\`notes\`](notes.md) for detail\n\n${BODY}`,
      );
      write(root, "skills/expertise/rules/notes.md", "# Notes\n");
      expect(validate(root).code).toBe(0);
    });

    test("passes an expertise skill that names another expertise skill", () => {
      const root = kinds(`Use \`rules\` and \`other\` here.\n\n${BODY}`);
      expect(validate(root).code).toBe(0);
    });

    test("passes a workflow skill that names a workflow skill", () => {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", skill(REVIEW, `Then load \`plan\`.\n\n${BODY}`));
      write(root, "skills/workflow/plan/SKILL.md", skill(REVIEW.replace("demo", "plan"), BODY));
      expect(validate(root).code).toBe(0);
    });
  });

  describe("shared text", () => {
    const TEN = "every task names its route before the first edit lands";
    const NINE = "every task names its route before the first edit";

    function withProse(path: string, text: string): string {
      const root = fixture();
      write(root, "skills/workflow/demo/SKILL.md", WELL_FORMED);
      write(root, path, text);
      return root;
    }

    test("fails a planted run of ten words a doc shares with a skill", () => {
      const root = withProse("docs/loops.md", `# Loops\n\nHere ${TEN} today.\n`);
      write(root, "skills/workflow/demo/references/steps.md", `# Steps\n\nNote that ${TEN}, always.\n`);
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "docs/loops.md and skills/workflow/demo/references/steps.md share a run of 10 words",
      );
      expect(run.output).toContain(`  ${TEN}`);
      expect(run.output).toContain("to resolve: keep it in one place and name it from the other");
    });

    test("matches across case, line breaks and Markdown punctuation", () => {
      const root = withProse(
        "README.md",
        "# Skills\n\n**Every task** names its `route`\nbefore the _first_ edit — lands.\n",
      );
      write(root, "agents/worker.md", `# Worker\n\n- ${TEN}\n`);
      const run = validate(root);
      expect(run.code).toBe(1);
      expect(run.output).toContain("README.md and agents/worker.md share a run of 10 words");
    });

    test("scans AGENTS.md", () => {
      const root = withProse("AGENTS.md", `# Rules\n\n${TEN}\n`);
      write(root, "docs/a.md", `# A\n\n${TEN}\n`);
      expect(validate(root).output).toContain("AGENTS.md and docs/a.md share a run of 10 words");
    });

    test("passes a run of nine words", () => {
      const root = withProse("docs/a.md", `# A\n\n${NINE} once.\n`);
      write(root, "docs/b.md", `# B\n\n${NINE} twice.\n`);
      expect(validate(root).code).toBe(0);
    });

    test("passes a link target two files share", () => {
      const link = "[the steps](../skills/workflow/demo/references/one/two/three/four/five/six/seven.md)";
      const root = withProse("docs/a.md", `# A\n\nSee ${link}.\n`);
      write(root, "docs/b.md", `# B\n\nRead ${link}.\n`);
      expect(validate(root).code).toBe(0);
    });

    test("passes a run repeated inside one file", () => {
      expect(validate(withProse("docs/a.md", `# A\n\n${TEN}.\n\n${TEN}.\n`)).code).toBe(0);
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
