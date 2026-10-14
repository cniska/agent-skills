import { existsSync, readdirSync, realpathSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { z } from "zod";
import { reportProblems, runMain } from "../lib/cli";
import { CodedError } from "../lib/coded-error";
import { type Frontmatter, frontmatter } from "../lib/frontmatter";
import { ROOT_DIR } from "../lib/paths";
import { readJson, readText } from "../lib/read-file";
import {
  SKILL_KIND_RULES,
  SKILL_KINDS,
  type SkillDir,
  type SkillKind,
  skillDirs,
  strayEntries,
} from "../lib/skills";

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
const SKILL_NAME = /`([a-z0-9]+(?:-[a-z0-9]+)*)`/g;
const SEE_ALSO = /^## See also$/;
const HEADING = /^## /;
const LINKED_TEXT = /\[[^\]\n]*\]\([^)\n]+\)/g;
const MANIFEST_SKILLS = SKILL_KINDS.map((kind) => `./skills/${kind}`);
const KIND_FOLDERS = SKILL_KINDS.map((kind) => `skills/${kind}/`).join(" and ");
const KIND_CHOICES = SKILL_KINDS.map((kind) => `skills/${kind}/ if it is ${SKILL_KIND_RULES[kind]}`).join(
  ", or ",
);
const NEW_SKILL = "the skill-writing skill";

const PluginManifest = z.looseObject({ skills: z.array(z.string()).optional() });

type Problem = { readonly message: string; readonly resolve: string };

type Doc = { readonly file: string; readonly shown: string; readonly text: string };

type Skill = {
  readonly name: string;
  readonly kind: SkillKind;
  readonly dir: string;
  readonly skillDoc: Doc;
  readonly docs: readonly Doc[];
  readonly declaredName: string | null;
  readonly description: string | null;
};

type NumberedLine = { readonly shown: string; readonly inSeeAlso: boolean };

type SkillNames = { readonly all: ReadonlySet<string>; readonly workflow: ReadonlySet<string> };

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

function numberedLines(text: string): NumberedLine[] {
  let inSeeAlso = false;
  return text.split("\n").map((line, index) => {
    if (HEADING.test(line)) inSeeAlso = SEE_ALSO.test(line);
    return { shown: `  ${index + 1}:${line}`, inSeeAlso };
  });
}

function outsideSeeAlso(text: string): string[] {
  return numberedLines(text)
    .filter((line) => !line.inSeeAlso)
    .map((line) => line.shown);
}

function seeAlsoLines(text: string): string[] {
  return numberedLines(text)
    .filter((line) => line.inSeeAlso)
    .map((line) => line.shown);
}

function unknownNames(line: string, skills: ReadonlySet<string>): string[] {
  return [...line.replace(LINKED_TEXT, "").matchAll(SKILL_NAME)]
    .map((match) => match[1] ?? "")
    .filter((name) => !skills.has(name));
}

function seeAlsoProblems({ docs }: Skill, skills: ReadonlySet<string>): string[] {
  return docs.flatMap((doc) =>
    seeAlsoLines(doc.text).flatMap((line) =>
      unknownNames(line, skills).map((name) =>
        withDetail(`## See also names '${name}', which is no skill in this repo, in ${doc.shown}`, [line]),
      ),
    ),
  );
}

function routeProblems({ kind, docs }: Skill, workflow: ReadonlySet<string>): string[] {
  if (kind !== "expertise") return [];
  return docs.flatMap((doc) => {
    const lines = outsideSeeAlso(doc.text).filter((line) =>
      [...line.matchAll(SKILL_NAME)].some((match) => workflow.has(match[1] ?? "")),
    );
    if (lines.length === 0) return [];
    return [withDetail(`expertise skill names a workflow skill outside ## See also in ${doc.shown}`, lines)];
  });
}

function namedModelProblems(docs: readonly Doc[]): string[] {
  return docs.flatMap((doc) => {
    const lines = modelLines(doc.text);
    if (lines.length === 0) return [];
    return [withDetail(`named model in ${doc.shown}`, lines)];
  });
}

function modelProblems({ docs }: Skill): string[] {
  return namedModelProblems(docs);
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

const SEE_ALSO_RESOLVE =
  "name a skill that exists under skills/, or say it in plain words outside backticks if it is not a skill";

const ROUTE_RESOLVE =
  "state the rule without loading or routing to the workflow skill, and name it under ## See also if a reader needs it";

function load(root: string, { name, kind, dir }: SkillDir): Loaded {
  const skillFile = join(dir, "SKILL.md");
  if (!existsSync(skillFile)) {
    return refused(
      `missing SKILL.md in ${name}`,
      `add the SKILL.md with ${NEW_SKILL}, or remove the directory if it is not a skill`,
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
      kind,
      dir,
      skillDoc,
      docs,
      declaredName: textField(fields, "name"),
      description: textField(fields, "description"),
    },
  };
}

function skillProblems(skill: Skill, names: SkillNames): Problem[] {
  return [
    ...CHECKS.flatMap(({ resolve, problems }) => problems(skill).map((message) => ({ message, resolve }))),
    ...routeProblems(skill, names.workflow).map((message) => ({ message, resolve: ROUTE_RESOLVE })),
    ...seeAlsoProblems(skill, names.all).map((message) => ({ message, resolve: SEE_ALSO_RESOLVE })),
  ];
}

function proseDocs(root: string): Doc[] {
  const readme = join(root, "README.md");
  const docsDir = join(root, "docs");
  const files = [
    ...(existsSync(readme) ? [readme] : []),
    ...(existsSync(docsDir) ? markdownFiles(docsDir) : []),
  ];
  return files.map((file) => readDoc(root, file));
}

function proseProblems(root: string): Problem[] {
  return namedModelProblems(proseDocs(root)).map((message) => ({
    message,
    resolve: "describe how to pick a fast, balanced or powerful tier instead of naming a model",
  }));
}

function strayProblems(skillsDir: string): Problem[] {
  return strayEntries(skillsDir).map((entry) => ({
    message: `skills/${entry} is outside ${KIND_FOLDERS}`,
    resolve: `move each skill into ${KIND_CHOICES}`,
  }));
}

function duplicateProblems(skills: readonly SkillDir[]): Problem[] {
  const names = skills.map((skill) => skill.name);
  return [...new Set(names.filter((name, index) => names.indexOf(name) !== index))].map((name) => ({
    message: `skill ${name} sits in more than one of ${KIND_FOLDERS}`,
    resolve: `keep each skill in exactly one of ${KIND_FOLDERS}`,
  }));
}

function manifestProblems(root: string): Problem[] {
  const path = join(root, ".claude-plugin", "plugin.json");
  if (!existsSync(path)) return [];
  const listed = readJson(path, PluginManifest).skills ?? [];
  if (listed.join("\n") === MANIFEST_SKILLS.join("\n")) return [];
  return [
    {
      message: `.claude-plugin/plugin.json lists skills [${listed.join(", ")}], not [${MANIFEST_SKILLS.join(", ")}]`,
      resolve: `set "skills" in .claude-plugin/plugin.json to ${JSON.stringify(MANIFEST_SKILLS)}, so the plugin loads every skill folder`,
    },
  ];
}

function byResolve(problems: readonly Problem[]): Map<string, string[]> {
  const groups = new Map<string, string[]>();
  for (const { message, resolve } of problems) groups.set(resolve, [...(groups.get(resolve) ?? []), message]);
  return groups;
}

runMain((args) => {
  if (args.length > 1) throw new CodedError("usage", { usage: USAGE, problem: "takes at most one root" });
  const root = resolve(args[0] ?? ROOT_DIR);
  const skillsDir = join(root, "skills");
  if (!existsSync(skillsDir)) throw new CodedError("skills_missing", { dir: root });
  const skills = skillDirs(skillsDir);
  const names: SkillNames = {
    all: new Set(skills.map((skill) => skill.name)),
    workflow: new Set(skills.filter((skill) => skill.kind === "workflow").map((skill) => skill.name)),
  };
  const problems = [
    ...strayProblems(skillsDir),
    ...duplicateProblems(skills),
    ...skills.flatMap((skillDir) => {
      const loaded = load(root, skillDir);
      return loaded.kind === "skill" ? skillProblems(loaded.skill, names) : [loaded.problem];
    }),
    ...manifestProblems(root),
    ...proseProblems(root),
  ];
  for (const [resolve, messages] of byResolve(problems)) {
    reportProblems(
      messages.map((message) => `ERROR: ${message}`),
      resolve,
    );
  }
  if (problems.length === 0) console.log("OK: skill validation passed");
});
