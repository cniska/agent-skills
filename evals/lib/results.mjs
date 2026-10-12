import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export const resultsDir = fileURLToPath(new URL("../results", import.meta.url));

export function loadResult(path) {
  const result = JSON.parse(readFileSync(path, "utf8"));
  if (!Array.isArray(result.cases)) throw new Error(`${path} is not an eval result: it has no cases list`);
  return result.cases.map((c) => ({ name: c.name, arms: Object.entries(c.arms ?? {}) }));
}

export function newestRun() {
  if (!existsSync(resultsDir)) return null;
  const runs = readdirSync(resultsDir)
    .filter((d) => existsSync(join(resultsDir, d, "head.json")))
    .sort();
  if (runs.length === 0) return null;
  const dir = join(resultsDir, runs.at(-1));
  const base = join(dir, "base.json");
  return existsSync(base) ? [base, join(dir, "head.json")] : [join(dir, "head.json")];
}
