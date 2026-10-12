#!/usr/bin/env node
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { cases } from "./cases.mjs";
import { loadResult } from "./results.mjs";

const USAGE = "usage: keep-trace.mjs <head.json|base.json> <case> <run-index> <label>";

function die(message, code = 1) {
  console.error(`keep-trace.mjs: ${message}`);
  process.exit(code);
}

const args = process.argv.slice(2);
if (args.length !== 4) die(USAGE, 2);
const [resultPath, caseName, indexText, label] = args;
if (!/^\d+$/.test(indexText)) die(`run index must be a number: ${indexText}`, 2);
if (!/^[A-Za-z0-9._-]+$/.test(label)) die(`label must be a plain file name: ${label}`, 2);

const target = cases().find((c) => c.name === caseName);
if (!target) die(`no case ${caseName} under evals/`);
const result = loadResult(resultPath).find((c) => c.name === caseName);
if (!result) die(`case ${caseName} is not in ${resultPath}`);
if (result.arms.length !== 1) die(`case ${caseName} has ${result.arms.length} arms; the runner produces one`);
const run = result.arms[0][1][Number(indexText)];
if (!run) die(`no run ${indexText} in case ${caseName}`);
if (!run.tracePath || !existsSync(run.tracePath)) die(`trace is gone: ${run.tracePath} (rerun with --keep-temp)`);

const destination = join(target.dir, "traces", `${label}.jsonl`);
mkdirSync(join(target.dir, "traces"), { recursive: true });
copyFileSync(run.tracePath, destination);
console.log(`evals/${caseName}/traces/${label}.jsonl`);
