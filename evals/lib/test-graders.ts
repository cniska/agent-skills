import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";
import { cases, type EvalCase } from "./cases";
import { reportProblems, runMain } from "./cli";
import { grade, loadGraders } from "./grader";
import { readJson } from "./json-file";
import { parseTrace } from "./trace";

const Verdict = z.enum(["pass", "fail"]);
const Expected = z.record(
  z.string(),
  z.strictObject({
    workspace: z.string().nullable().default(null),
    expect: z.record(z.string(), Verdict).default({}),
  }),
);

function checkCase({ name, dir }: EvalCase): string[] {
  const expectedPath = join(dir, "traces", "expected.json");
  if (!existsSync(expectedPath)) return [`${name}: no traces/expected.json`];
  const problems: string[] = [];
  const graders = loadGraders(dir);
  const seen = new Map(graders.map((g) => [g.name, new Set<z.infer<typeof Verdict>>()]));
  for (const [file, entry] of Object.entries(readJson(expectedPath, Expected))) {
    const path = join(dir, "traces", file);
    const trace = parseTrace(readFileSync(path, "utf8"), path);
    const workspace = entry.workspace === null ? null : join(dir, "traces", entry.workspace);
    const verdicts = new Map(graders.map((g) => [g.name, grade(g, trace, workspace)]));
    for (const [grader, verdict] of verdicts) {
      if (verdict === null) continue;
      seen.get(grader)?.add(verdict ? "pass" : "fail");
    }
    for (const [grader, want] of Object.entries(entry.expect)) {
      if (!verdicts.has(grader)) {
        problems.push(`${name}/${file}: expects ${grader}, but the case has no grader by that name`);
        continue;
      }
      const verdict = verdicts.get(grader);
      if (verdict === null) {
        problems.push(`${name}/${file}: expects ${grader} to ${want}, but it cannot be checked offline`);
        continue;
      }
      const got = verdict ? "pass" : "fail";
      if (want !== got) problems.push(`${name}/${file}: ${grader} gave ${got}, expected ${want}`);
    }
  }
  for (const [grader, verdicts] of seen) {
    if (verdicts.size !== 1) continue;
    problems.push(
      `${name}: ${grader} is never seen ${verdicts.has("pass") ? "failing" : "passing"} on the saved traces`,
    );
  }
  return problems;
}

runMain(() => {
  const all = cases();
  const problems = all.flatMap(checkCase);
  reportProblems(problems);
  if (problems.length === 0) console.log(`graders hold on saved traces for ${all.length} cases`);
});
