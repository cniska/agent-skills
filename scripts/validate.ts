import { existsSync, readdirSync, realpathSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { reportProblems, runMain } from "../lib/cli";
import { CodedError } from "../lib/coded-error";
import { type Frontmatter, frontmatter } from "../lib/frontmatter";
import { ROOT_DIR } from "../lib/paths";
import { readText } from "../lib/read-file";

const USAGE = "usage: bun scripts/validate.ts [root]";
const IMPERATIVE_VERBS = [
  "apply",
  "implement",
  "review",
  "audit",
  "debug",
  "deprecate",
  "design",
  "manage",
  "create",
  "run",
  "simplify",
  "drive",
  "write",
  "test",
  "explain",
  "search",
] as const;
const IMPERATIVE = new Set<string>(IMPERATIVE_VERBS);
const MODEL_NAME = /(?<!\w)(sonnet|opus|haiku|fable|gpt|gemini|llama|mistral|grok|deepseek|qwen)(?!\w)/i;
const FIRST_WORD = /^\s*([A-Za-z-]+)/;
const RED_FLAGS = /^## Red flags$/m;
const ANTI_PATTERNS = /^## Anti-patterns$/m;
const LINK = /\]\(([^)\n]+)\)/g;
const EXTERNAL_LINK = /^(https?:|mailto:|#)/;

type Problem = { readonly message: string; readonly resolve: string };

type Doc = { readonly file: string; readonly shown: string; readonly text: string };

type Skill = {
  readonly name: string;
  readonly dir: string;
  readonly skillDoc: Doc;
  readonly docs: readonly Doc[];
  readonly declaredName: string | null;
  readonly description: string | null;
};

type Loaded =
  | { readonly kind: "skill"; readonly skill: Skill }
  | { readonly kind: "refused"; readonly problem: Problem };

function refused(message: string, resolve: string): Loaded {
  return { kind: "refused", problem: { message, resolve } };
}

function withDetail(message: string, detail: readonly string[]): string {
  return [message, ...detail].join("\n");
}

function readDoc(root: string, file: string): Doc {
  return { file, shown: relative(root, file), text: readText(file) };
}

function markdownFiles(dir: string): string[] {
  return readdirSync(dir, { recursive: true, withFileTypes: true })
    .filter((entry) => !entry.isDirectory() && entry.name.endsWith(".md"))
    .map((entry) => join(entry.parentPath, entry.name))
    .sort();
}

function textField(fields: Frontmatter, key: string): string | null {
  const value = fields[key];
  return typeof value === "string" && value !== "" ? value : null;
}

function modelLines(text: string): string[] {
  return text.split("\n").flatMap((line, index) => (MODEL_NAME.test(line) ? [`  ${index + 1}:${line}`] : []));
}

function firstWord(description: string): string {
  return (description.match(FIRST_WORD)?.[1] ?? description).toLowerCase();
}

function resolvesInside(skillRoot: string, doc: Doc, target: string): boolean {
  const file = resolve(dirname(doc.file), target);
  return existsSync(file) && realpathSync(file).startsWith(skillRoot + sep);
}

function fieldProblems({ skillDoc, declaredName, description }: Skill): string[] {
  if (declaredName !== null && description !== null) return [];
  return [`frontmatter requires both name and description in ${skillDoc.shown}`];
}

function nameProblems({ name, skillDoc, declaredName }: Skill): string[] {
  if (declaredName === name) return [];
  return [`frontmatter name '${declaredName ?? ""}' must match directory '${name}' in ${skillDoc.shown}`];
}

function imperativeProblems({ skillDoc, description }: Skill): string[] {
  const word = description === null ? "" : firstWord(description);
  if (IMPERATIVE.has(word)) return [];
  return [
    withDetail(`description should start with an imperative verb in ${skillDoc.shown}`, [
      `  got first word: '${word}'`,
    ]),
  ];
}

function redFlagsProblems({ skillDoc }: Skill): string[] {
  return RED_FLAGS.test(skillDoc.text) ? [] : [`missing '## Red flags' section in ${skillDoc.shown}`];
}

function antiPatternsProblems({ skillDoc }: Skill): string[] {
  if (!ANTI_PATTERNS.test(skillDoc.text)) return [];
  return [`use '## Red flags' instead of '## Anti-patterns' in ${skillDoc.shown}`];
}

function linkProblems({ name, dir, docs }: Skill): string[] {
  const skillRoot = realpathSync(dir);
  return docs.flatMap((doc) =>
    [...doc.text.matchAll(LINK)]
      .map((match) => match[1] ?? "")
      .filter((link) => !EXTERNAL_LINK.test(link))
      .filter((link) => {
        const target = link.split("#")[0] ?? "";
        return target !== "" && !resolvesInside(skillRoot, doc, target);
      })
      .map(
        (link) =>
          `link '${link}' in ${name} must name a file inside the skill's own directory (in ${doc.shown})`,
      ),
  );
}

function modelProblems({ docs }: Skill): string[] {
  return docs.flatMap((doc) => {
    const lines = modelLines(doc.text);
    if (lines.length === 0) return [];
    return [withDetail(`named model in ${doc.shown} (use a fast/balanced/powerful tier instead)`, lines)];
  });
}

const CHECKS: readonly { readonly resolve: string; readonly problems: (skill: Skill) => string[] }[] = [
  {
    resolve: "give the SKILL.md frontmatter both a name: line and a description: line",
    problems: fieldProblems,
  },
  {
    resolve: "set the frontmatter name to the directory's name, or rename the directory to match it",
    problems: nameProblems,
  },
  {
    resolve: `start the description with one of: ${IMPERATIVE_VERBS.join(", ")}`,
    problems: imperativeProblems,
  },
  {
    resolve: "end SKILL.md with a '## Red flags' section listing the skill's failure modes",
    problems: redFlagsProblems,
  },
  { resolve: "rename the '## Anti-patterns' heading to '## Red flags'", problems: antiPatternsProblems },
  {
    resolve:
      "point the link at a file that exists inside the skill's own directory, or name another skill by bare name under ## See also",
    problems: linkProblems,
  },
  { resolve: "name a fast, balanced or powerful tier instead of the model", problems: modelProblems },
];

function load(root: string, name: string): Loaded {
  const dir = join(root, "skills", name);
  const skillFile = join(dir, "SKILL.md");
  if (!existsSync(skillFile)) {
    return refused(
      `missing SKILL.md in ${name}`,
      'add the SKILL.md with mise run new-skill <name> "<description>", or remove the directory if it is not a skill',
    );
  }
  const skillDoc = readDoc(root, skillFile);
  let fields: Frontmatter;
  try {
    fields = frontmatter(skillDoc.text, skillDoc.shown);
  } catch (error) {
    if (!(error instanceof CodedError) || error.code !== "frontmatter_unsupported") throw error;
    return refused(error.message, error.resolve);
  }
  if (Object.keys(fields).length === 0) {
    return refused(
      `missing YAML frontmatter in ${skillDoc.shown}`,
      "start SKILL.md with a --- block holding name: and description: lines, closed by ---",
    );
  }
  const docs = markdownFiles(dir).map((file) => (file === skillFile ? skillDoc : readDoc(root, file)));
  return {
    kind: "skill",
    skill: {
      name,
      dir,
      skillDoc,
      docs,
      declaredName: textField(fields, "name"),
      description: textField(fields, "description"),
    },
  };
}

function skillProblems(skill: Skill): Problem[] {
  return CHECKS.flatMap(({ resolve, problems }) => problems(skill).map((message) => ({ message, resolve })));
}

function readmeProblems(root: string): Problem[] {
  const path = join(root, "README.md");
  if (!existsSync(path)) return [];
  const lines = modelLines(readText(path));
  if (lines.length === 0) return [];
  return [
    {
      message: withDetail(
        "named model in README.md (describe how to pick a tier, not today's models)",
        lines,
      ),
      resolve: "describe how to pick a fast, balanced or powerful tier instead of naming a model",
    },
  ];
}

function skillNames(root: string): string[] {
  const dir = join(root, "skills");
  if (!existsSync(dir)) throw new CodedError("skills_missing", { dir: root });
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function byResolve(problems: readonly Problem[]): Map<string, string[]> {
  const groups = new Map<string, string[]>();
  for (const { message, resolve } of problems) groups.set(resolve, [...(groups.get(resolve) ?? []), message]);
  return groups;
}

runMain((args) => {
  if (args.length > 1) throw new CodedError("usage", { usage: USAGE, problem: "takes at most one root" });
  const root = resolve(args[0] ?? ROOT_DIR);
  const problems = [
    ...skillNames(root).flatMap((name) => {
      const loaded = load(root, name);
      return loaded.kind === "skill" ? skillProblems(loaded.skill) : [loaded.problem];
    }),
    ...readmeProblems(root),
  ];
  for (const [resolve, messages] of byResolve(problems)) {
    reportProblems(
      messages.map((message) => `ERROR: ${message}`),
      resolve,
    );
  }
  if (problems.length === 0) console.log("OK: skill validation passed");
});
