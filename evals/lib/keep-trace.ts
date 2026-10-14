import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { join, relative } from "node:path";
import { runMain } from "../../lib/cli";
import { CodedError } from "../../lib/coded-error";
import { ROOT_DIR } from "../../lib/paths";
import { cases } from "./cases";
import { loadResult } from "./results";

const USAGE = "usage: mise run eval:keep <head.json|base.json> <case> <run-index> <label>";
const RUN_INDEX = /^\d+$/;
const PLAIN_LABEL = /^[A-Za-z0-9._-]+$/;

runMain((args) => {
  const [resultPath, caseName, indexText, label] = args;
  if (args.length !== 4 || !resultPath || !caseName || !indexText || !label) {
    throw new CodedError("usage", { usage: USAGE, problem: null });
  }
  if (!RUN_INDEX.test(indexText))
    throw new CodedError("usage", { usage: USAGE, problem: `run index must be a number: ${indexText}` });
  if (!PLAIN_LABEL.test(label))
    throw new CodedError("usage", { usage: USAGE, problem: `label must be a plain file name: ${label}` });
  const index = Number(indexText);

  const target = cases().find((c) => c.name === caseName);
  if (!target) throw new CodedError("case_missing", { name: caseName });
  const result = loadResult(resultPath).find((c) => c.name === caseName);
  if (!result) throw new CodedError("result_case_missing", { name: caseName, path: resultPath });
  const [arm] = result.arms;
  if (arm === undefined || result.arms.length !== 1) {
    throw new CodedError("arm_count", { name: caseName, arms: result.arms.length });
  }
  const run = arm[1][index];
  if (!run) throw new CodedError("run_missing", { name: caseName, index });
  if (run.tracePath === null) throw new CodedError("trace_unrecorded", { name: caseName, index });
  if (!existsSync(run.tracePath)) throw new CodedError("trace_gone", { path: run.tracePath });

  const saved = join(target.dir, "traces", `${label}.jsonl`);
  mkdirSync(join(target.dir, "traces"), { recursive: true });
  copyFileSync(run.tracePath, saved);
  console.log(relative(ROOT_DIR, saved));
});
