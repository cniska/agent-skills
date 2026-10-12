#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { cases } from "./cases.mjs";
import { grade, loadGraders } from "./graders.mjs";

function checkCase({ name, dir }) {
  const expectedPath = join(dir, "traces", "expected.json");
  if (!existsSync(expectedPath)) return [`${name}: no traces/expected.json`];
  const problems = [];
  const graders = loadGraders(dir);
  const seen = Object.fromEntries(graders.map((g) => [g.name, new Set()]));
  for (const [file, entry] of Object.entries(JSON.parse(readFileSync(expectedPath, "utf8")))) {
    const trace = readFileSync(join(dir, "traces", file), "utf8");
    const workspace = entry.workspace ? join(dir, "traces", entry.workspace) : null;
    for (const g of graders) {
      const verdict = grade(g, trace, workspace);
      if (verdict === null) continue;
      const got = verdict ? "pass" : "fail";
      seen[g.name].add(got);
      const want = entry.expect?.[g.name];
      if (want && want !== got) problems.push(`${name}/${file}: ${g.name} gave ${got}, expected ${want}`);
    }
  }
  for (const g of graders) {
    const verdicts = seen[g.name];
    if (verdicts.size === 0 || verdicts.size === 2) continue;
    problems.push(`${name}: ${g.name} is never seen ${verdicts.has("pass") ? "failing" : "passing"} on the saved traces`);
  }
  return problems;
}

const all = cases();
const problems = all.flatMap(checkCase);
if (problems.length) {
  console.error(problems.join("\n"));
  process.exit(1);
}
console.log(`graders hold on saved traces for ${all.length} cases`);
