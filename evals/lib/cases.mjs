#!/usr/bin/env node
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { frontmatter } from "./frontmatter.mjs";

export const evalsDir = fileURLToPath(new URL("..", import.meta.url));

function isCase(dir) {
  return existsSync(join(dir, "prompt.md")) || existsSync(join(dir, "case.yaml"));
}

function caseTags(dir) {
  const prompt = join(dir, "prompt.md");
  if (!existsSync(prompt)) return [];
  const tags = frontmatter(readFileSync(prompt, "utf8")).tags ?? [];
  if (!Array.isArray(tags)) throw new Error(`${prompt}: tags must be an inline list, such as tags: [git]`);
  return tags;
}

export function cases() {
  return readdirSync(evalsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && isCase(join(evalsDir, d.name)))
    .map((d) => ({ name: d.name, dir: join(evalsDir, d.name), tags: caseTags(join(evalsDir, d.name)) }));
}

export function casesFor(skill) {
  return cases().filter((c) => skill === "" || c.tags.includes(skill));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [skill = ""] = process.argv.slice(2);
  for (const c of casesFor(skill)) console.log(c.name);
}
