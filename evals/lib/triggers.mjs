#!/usr/bin/env node
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { frontmatter } from "./frontmatter.mjs";

const repo = new URL("../..", import.meta.url).pathname;
const skillsDir = join(repo, "skills");
const triggersDir = join(repo, "evals", "triggers");
const COLLISION_LIMIT = 0.5;
const SUFFIXES = ["ations", "ation", "ings", "ing", "edly", "ed", "ies", "es", "s", "ly", "ment"];
const STOP_WORDS = new Set(
  ("a an and are as at be by for from has have i in is it its me my of on or our so that the " +
    "this to was we what when where which who will with you your can do does if into it's just not " +
    "use used using should would could also any all").split(" "),
);

function stem(word) {
  const suffix = SUFFIXES.find((s) => word.length > s.length + 3 && word.endsWith(s));
  return suffix ? word.slice(0, -suffix.length) : word;
}

function terms(text) {
  return text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length > 1 && !STOP_WORDS.has(w))
    .map(stem);
}

function description(path) {
  const value = frontmatter(readFileSync(path, "utf8")).description;
  return typeof value === "string" ? value : "";
}

function cosine(a, b) {
  let dot = 0;
  for (const [t, w] of a) dot += w * (b.get(t) ?? 0);
  const norm = (v) => Math.sqrt([...v.values()].reduce((s, w) => s + w * w, 0));
  return dot === 0 ? 0 : dot / (norm(a) * norm(b));
}

function buildIndex() {
  const skills = readdirSync(skillsDir)
    .filter((name) => existsSync(join(skillsDir, name, "SKILL.md")))
    .map((name) => ({ name, text: description(join(skillsDir, name, "SKILL.md")) }))
    .filter((s) => s.text);
  const docFreq = new Map();
  for (const s of skills) for (const t of new Set(terms(s.text))) docFreq.set(t, (docFreq.get(t) ?? 0) + 1);
  const idf = (t) => Math.log((1 + skills.length) / (1 + (docFreq.get(t) ?? 0))) + 1;
  const vector = (text) => {
    const tf = new Map();
    for (const t of terms(text)) tf.set(t, (tf.get(t) ?? 0) + 1);
    return new Map([...tf].map(([t, n]) => [t, n * idf(t)]));
  };
  for (const s of skills) s.vector = vector(s.text);
  const ranking = (prompt) => {
    const v = vector(prompt);
    return skills.map((s) => ({ name: s.name, score: cosine(v, s.vector) })).sort((a, b) => b.score - a.score);
  };
  return { skills, ranking };
}

function scoreSkill(skill, spec, ranking) {
  const positives = spec.positive ?? [];
  const misses = [];
  for (const { prompt } of positives) {
    const ranks = ranking(prompt);
    const rank = ranks.findIndex((r) => r.name === skill) + 1;
    if (rank !== 1) misses.push(`    #${rank}: "${prompt}" (first: ${ranks[0].name})`);
  }
  const wrong = (spec.negative ?? [])
    .filter(({ prompt }) => ranking(prompt)[0].name === skill)
    .map(({ prompt, owner }) => `    loads for: "${prompt}"${owner ? ` (belongs to ${owner})` : ""}`);
  return { total: positives.length, hit: positives.length - misses.length, misses, wrong };
}

function collisions(skills) {
  const errors = [];
  for (let i = 0; i < skills.length; i += 1) {
    for (let j = i + 1; j < skills.length; j += 1) {
      const sim = cosine(skills[i].vector, skills[j].vector);
      if (sim >= COLLISION_LIMIT) errors.push(`${skills[i].name} and ${skills[j].name} descriptions are ${Math.round(sim * 100)}% alike`);
    }
  }
  return errors;
}

const { skills, ranking } = buildIndex();
const files = existsSync(triggersDir) ? readdirSync(triggersDir).filter((f) => f.endsWith(".json")).sort() : [];
const problems = [];
let positives = 0;
let firsts = 0;

for (const file of files) {
  const skill = file.replace(/\.json$/, "");
  if (!skills.some((s) => s.name === skill)) {
    problems.push(`${file}: no skill named ${skill}`);
    continue;
  }
  const result = scoreSkill(skill, JSON.parse(readFileSync(join(triggersDir, file), "utf8")), ranking);
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
if (problems.length) {
  console.error(`\n${problems.join("\n")}`);
  process.exit(1);
}
