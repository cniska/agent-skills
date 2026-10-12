import { readFileSync } from "node:fs";
import { runMain } from "./cli";
import { CodedError } from "./coded-error";
import { grade, loadGraders } from "./grader";
import { parseTrace } from "./trace";

const USAGE = "usage: prove.ts <case-dir> [--workspace <dir>] <trace.jsonl>...";

function label(verdict: boolean | null): string {
  if (verdict === null) return "not-checked";
  return verdict ? "pass" : "FAIL";
}

function parseArgs(args: readonly string[]): { caseDir: string; workspace: string | null; traces: string[] } {
  const [caseDir, flag, dir, ...rest] = args;
  const withWorkspace = flag === "--workspace";
  const traces = withWorkspace ? rest : args.slice(1);
  if (caseDir === undefined || (withWorkspace && dir === undefined) || traces.length === 0) {
    throw new CodedError("usage", { problem: USAGE });
  }
  return { caseDir, workspace: withWorkspace ? (dir ?? null) : null, traces };
}

runMain((args) => {
  const { caseDir, workspace, traces } = parseArgs(args);
  const graders = loadGraders(caseDir);
  for (const path of traces) {
    const trace = parseTrace(readFileSync(path, "utf8"), path);
    const verdicts = graders.map((g) => `${g.name}=${label(grade(g, trace, workspace))}`);
    console.log(`${path}\n  ${verdicts.join("\n  ")}`);
  }
});
