#!/usr/bin/env node
import { loadResult, newestRun } from "./results.mjs";

function failedGraders(runs) {
  const fails = {};
  for (const r of runs) {
    for (const g of r.graders ?? []) {
      if (g.scored && !g.passed) fails[g.name] = (fails[g.name] ?? 0) + 1;
    }
  }
  return fails;
}

function armLine(runs) {
  const scores = runs.map((r) => Math.round((r.score ?? 0) * 100));
  const mean = scores.length ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : 0;
  const fails = Object.entries(failedGraders(runs));
  const failed = fails.length ? `  failed: ${fails.map(([n, k]) => `${n}×${k}`).join(", ")}` : "";
  return `${String(mean).padStart(3)}%  [${scores.join(" ")}]${failed}`;
}

function rowsByCase(path, side) {
  const rows = {};
  for (const c of loadResult(path)) {
    for (const [arm, runs] of c.arms) {
      (rows[c.name] ??= []).push({ side: side ? `${side} ${arm}` : arm, text: armLine(runs) });
    }
  }
  return rows;
}

const args = process.argv.slice(2);
const paths = args.length ? args : newestRun() ?? [];
if (paths.length === 0 || paths.length > 2) {
  console.error("usage: summary.mjs [<head.json> | <base.json> <head.json>]; with none, reads the newest run under evals/results/");
  process.exit(2);
}
const tables = paths.length === 2 ? [rowsByCase(paths[0], "base"), rowsByCase(paths[1], "head")] : [rowsByCase(paths[0], "")];
const names = [...new Set(tables.flatMap((t) => Object.keys(t)))].sort();
const width = Math.max(...tables.flatMap((t) => Object.values(t).flat().map((r) => r.side.length)));
for (const name of names) {
  console.log(name);
  for (const t of tables) for (const r of t[name] ?? []) console.log(`  ${r.side.padEnd(width)}  ${r.text}`);
}
