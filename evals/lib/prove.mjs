#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { grade, loadGraders } from "./graders.mjs";

const USAGE = "usage: prove.mjs <case-dir> [--workspace <dir>] <trace.jsonl>...";

const args = process.argv.slice(2);
const caseDir = args.shift();
let workspace = null;
if (args[0] === "--workspace") {
  args.shift();
  workspace = args.shift();
}
if (!caseDir || args.length === 0) {
  console.error(USAGE);
  process.exit(2);
}

function label(verdict) {
  if (verdict === null) return "not-checked";
  return verdict ? "pass" : "FAIL";
}

const graders = loadGraders(caseDir);
for (const path of args) {
  const trace = readFileSync(path, "utf8");
  const results = graders.map((g) => `${g.name}=${label(grade(g, trace, workspace))}`);
  console.log(`${path}\n  ${results.join("\n  ")}`);
}
