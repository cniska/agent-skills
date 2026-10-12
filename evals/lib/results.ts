import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";
import { EVALS_DIR } from "./cases";
import { readJson } from "./json-file";

export const RESULTS_DIR = join(EVALS_DIR, "results");

const orNull = <Schema extends z.ZodType>(schema: Schema) =>
  schema.nullish().transform((value) => value ?? null);

const GraderResult = z.looseObject({
  name: z.string(),
  scored: z.boolean().default(false),
  passed: z.boolean().default(false),
});

const Run = z.looseObject({
  score: orNull(z.number()),
  tracePath: orNull(z.string()),
  graders: z.array(GraderResult).default([]),
});

const Result = z.looseObject({
  cases: z.array(z.looseObject({ name: z.string(), arms: z.record(z.string(), z.array(Run)).default({}) })),
});

export type Run = z.infer<typeof Run>;
export type CaseResult = {
  readonly name: string;
  readonly arms: readonly (readonly [string, readonly Run[]])[];
};
export type RunPaths = readonly [head: string] | readonly [base: string, head: string];

export function loadResult(path: string): CaseResult[] {
  return readJson(path, Result).cases.map((c) => ({ name: c.name, arms: Object.entries(c.arms) }));
}

export function newestRun(): RunPaths | null {
  const newest = existsSync(RESULTS_DIR)
    ? readdirSync(RESULTS_DIR)
        .filter((dir) => existsSync(join(RESULTS_DIR, dir, "head.json")))
        .sort()
        .at(-1)
    : undefined;
  if (newest === undefined) return null;
  const dir = join(RESULTS_DIR, newest);
  const base = join(dir, "base.json");
  return existsSync(base) ? [base, join(dir, "head.json")] : [join(dir, "head.json")];
}
