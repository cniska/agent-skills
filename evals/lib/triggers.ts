import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";
import { reportProblems, runMain } from "../../lib/cli";
import { CodedError } from "../../lib/coded-error";
import { readFrontmatter } from "../../lib/frontmatter";
import { SKILLS_DIR } from "../../lib/paths";
import { readJson } from "../../lib/read-file";
import { skillDirs } from "../../lib/skills";
import { EVALS_DIR } from "./cases";

const TRIGGERS_DIR = join(EVALS_DIR, "triggers");
const COLLISION_LIMIT = 0.5;
const WORD_SPLIT = /[^a-z0-9]+/;
const SUFFIXES = ["ations", "ation", "ings", "ing", "edly", "ed", "ies", "es", "s", "ly", "ment"];
const STOP_WORDS = new Set(
  (
    "a an and are as at be by for from has have i in is it its me my of on or our so that the " +
    "this to was we what when where which who will with you your can do does if into it's just not " +
    "use used using should would could also any all"
  ).split(" "),
);

const TriggerSpec = z.strictObject({
  positive: z.array(z.strictObject({ prompt: z.string() })).default([]),
  negative: z.array(z.strictObject({ prompt: z.string(), owner: z.string().optional() })).default([]),
});

type Vector = ReadonlyMap<string, number>;
type Skill = { readonly name: string; readonly vector: Vector };
type Ranked = { readonly name: string; readonly score: number };

function stem(word: string): string {
  const suffix = SUFFIXES.find((s) => word.length > s.length + 3 && word.endsWith(s));
  return suffix ? word.slice(0, -suffix.length) : word;
}

function terms(text: string): string[] {
  return text
    .toLowerCase()
    .split(WORD_SPLIT)
    .filter((w) => w.length > 1 && !STOP_WORDS.has(w))
    .map(stem);
}

function description(path: string): string {
  const value = readFrontmatter(path).description;
  if (typeof value !== "string" || !value) {
    throw new CodedError("input_invalid", { path, problem: "frontmatter has no description to rank" });
  }
  return value;
}

function norm(v: Vector): number {
  return Math.sqrt([...v.values()].reduce((sum, w) => sum + w * w, 0));
}

function cosine(a: Vector, b: Vector): number {
  let dot = 0;
  for (const [term, weight] of a) dot += weight * (b.get(term) ?? 0);
  return dot === 0 ? 0 : dot / (norm(a) * norm(b));
}

function buildIndex(): { skills: Skill[]; ranking: (prompt: string) => Ranked[] } {
  const described = skillDirs(SKILLS_DIR)
    .filter(({ dir }) => existsSync(join(dir, "SKILL.md")))
    .map(({ name, dir }) => ({ name, text: description(join(dir, "SKILL.md")) }));
  const docFreq = new Map<string, number>();
  for (const s of described)
    for (const t of new Set(terms(s.text))) docFreq.set(t, (docFreq.get(t) ?? 0) + 1);
  const idf = (t: string) => Math.log((1 + described.length) / (1 + (docFreq.get(t) ?? 0))) + 1;
  const vector = (text: string): Vector => {
    const tf = new Map<string, number>();
    for (const t of terms(text)) tf.set(t, (tf.get(t) ?? 0) + 1);
    return new Map([...tf].map(([t, n]) => [t, n * idf(t)]));
  };
  const skills = described.map((s) => ({ name: s.name, vector: vector(s.text) }));
  const ranking = (prompt: string) => {
    const v = vector(prompt);
    return skills
      .map((s) => ({ name: s.name, score: cosine(v, s.vector) }))
      .sort((a, b) => b.score - a.score);
  };
  return { skills, ranking };
}

function scoreSkill(skill: string, spec: z.infer<typeof TriggerSpec>, ranking: (prompt: string) => Ranked[]) {
  const misses: string[] = [];
  for (const { prompt } of spec.positive) {
    const ranks = ranking(prompt);
    const rank = ranks.findIndex((r) => r.name === skill) + 1;
    if (rank !== 1) misses.push(`    #${rank}: "${prompt}" (first: ${ranks[0]?.name})`);
  }
  const wrong = spec.negative
    .filter(({ prompt }) => ranking(prompt)[0]?.name === skill)
    .map(({ prompt, owner }) => `    loads for: "${prompt}"${owner ? ` (belongs to ${owner})` : ""}`);
  return { total: spec.positive.length, hit: spec.positive.length - misses.length, misses, wrong };
}

function collisions(skills: readonly Skill[]): string[] {
  return skills.flatMap((a, i) =>
    skills.slice(i + 1).flatMap((b) => {
      const similarity = cosine(a.vector, b.vector);
      return similarity >= COLLISION_LIMIT
        ? [`${a.name} and ${b.name} descriptions are ${Math.round(similarity * 100)}% alike`]
        : [];
    }),
  );
}

runMain(() => {
  const { skills, ranking } = buildIndex();
  const files = existsSync(TRIGGERS_DIR)
    ? readdirSync(TRIGGERS_DIR)
        .filter((f) => f.endsWith(".json"))
        .sort()
    : [];
  const problems: string[] = [];
  let positives = 0;
  let firsts = 0;

  for (const file of files) {
    const skill = file.replace(/\.json$/, "");
    if (!skills.some((s) => s.name === skill)) {
      problems.push(`${file}: no skill named ${skill}`);
      continue;
    }
    const result = scoreSkill(skill, readJson(join(TRIGGERS_DIR, file), TriggerSpec), ranking);
    positives += result.total;
    firsts += result.hit;
    const wrongly = result.wrong.length ? `  wrongly first for ${result.wrong.length}` : "";
    console.log(`${skill}  first for ${result.hit}/${result.total}${wrongly}`);
    for (const line of [...result.misses, ...result.wrong]) console.log(line);
    for (const w of result.wrong) problems.push(`${skill}: ${w.trim()}`);
  }

  const rate = positives ? Math.round((firsts / positives) * 100) : 100;
  console.log(`\nfirst-place rate: ${rate}% (${firsts}/${positives}) across ${files.length} skills`);
  problems.push(...collisions(skills));
  reportProblems(
    problems,
    "reword the description of the skill a prompt loads wrongly, or of two descriptions that collide; fix a trigger file named for no skill",
  );
});
