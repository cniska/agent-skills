import { runMain } from "./cli";
import { CodedError } from "./coded-error";
import { loadResult, newestRun, RESULTS_DIR, type Run, type RunPaths } from "./results";

const USAGE =
  "usage: summary.ts [<head.json> | <base.json> <head.json>]; with none, reads the newest run under evals/results/";

type Row = { readonly side: string; readonly text: string };

function failedGraders(runs: readonly Run[]): Map<string, number> {
  const fails = new Map<string, number>();
  for (const run of runs) {
    for (const g of run.graders) {
      if (g.scored && !g.passed) fails.set(g.name, (fails.get(g.name) ?? 0) + 1);
    }
  }
  return fails;
}

function armLine(runs: readonly Run[]): string {
  const scores = runs.map((run) => (run.score === null ? null : Math.round(run.score * 100)));
  const scored = scores.filter((score) => score !== null);
  const mean = scored.length ? `${Math.round(scored.reduce((a, b) => a + b, 0) / scored.length)}%` : "-";
  const fails = [...failedGraders(runs)];
  const failed = fails.length
    ? `  failed: ${fails.map(([name, count]) => `${name}×${count}`).join(", ")}`
    : "";
  return `${mean.padStart(4)}  [${scores.map((score) => score ?? "-").join(" ")}]${failed}`;
}

function rowsByCase(path: string, side: string | null): Map<string, Row[]> {
  const rows = new Map<string, Row[]>();
  for (const c of loadResult(path)) {
    for (const [arm, runs] of c.arms) {
      const row = { side: side === null ? arm : `${side} ${arm}`, text: armLine(runs) };
      rows.set(c.name, [...(rows.get(c.name) ?? []), row]);
    }
  }
  return rows;
}

function runPaths(args: readonly string[]): RunPaths {
  const [first, second] = args;
  if (args.length > 2) throw new CodedError("usage", { problem: USAGE });
  if (first === undefined) {
    const newest = newestRun();
    if (newest === null) throw new CodedError("results-missing", { dir: RESULTS_DIR });
    return newest;
  }
  return second === undefined ? [first] : [first, second];
}

function tables(paths: RunPaths): Map<string, Row[]>[] {
  const [first, second] = paths;
  return second === undefined
    ? [rowsByCase(first, null)]
    : [rowsByCase(first, "base"), rowsByCase(second, "head")];
}

runMain((args) => {
  const all = tables(runPaths(args));
  const names = [...new Set(all.flatMap((t) => [...t.keys()]))].sort();
  const width = Math.max(...all.flatMap((t) => [...t.values()].flat().map((r) => r.side.length)));
  for (const name of names) {
    console.log(name);
    for (const t of all)
      for (const r of t.get(name) ?? []) console.log(`  ${r.side.padEnd(width)}  ${r.text}`);
  }
});
