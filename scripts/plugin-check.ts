import { existsSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { z } from "zod";
import { reportProblems, runMain } from "../lib/cli";
import { CodedError } from "../lib/coded-error";
import { readJson } from "../lib/read-file";

const USAGE = "usage: bun scripts/plugin-check.ts <checkout>";
const PLUGIN = "cniska-skills@cniska";
const SHORT_SHA = 12;

const Install = z.looseObject({
  scope: z.string(),
  projectPath: z.string().optional(),
  gitCommitSha: z.string().optional(),
});
type Install = z.infer<typeof Install>;

const Installs = z.looseObject({
  plugins: z.record(z.string(), z.array(Install)),
});

type Scope = { readonly name: "user" | "project"; readonly install: Install | null };

function installsPath(): string {
  const configDir = process.env.CLAUDE_CONFIG_DIR;
  const base = configDir === undefined || configDir === "" ? join(homedir(), ".claude") : configDir;
  return join(base, "plugins", "installed_plugins.json");
}

function headOf(checkout: string): string {
  const result = Bun.spawnSync(["git", "-C", checkout, "rev-parse", "HEAD"]);
  if (result.exitCode !== 0)
    throw new CodedError("checkout_invalid", { path: checkout, problem: result.stderr.toString().trim() });
  return result.stdout.toString().trim();
}

function samePath(left: string, right: string): boolean {
  return existsSync(left) && existsSync(right) && realpathSync(left) === realpathSync(right);
}

function problem(scope: Scope, head: string, checkout: string): string | null {
  const update = `claude plugin update ${PLUGIN} --scope ${scope.name}`;
  if (scope.install === null) return `ERROR: ${PLUGIN} has no ${scope.name}-scope install for ${checkout}`;
  const sha = scope.install.gitCommitSha ?? null;
  if (sha === head) return null;
  const at = sha === null ? "no recorded commit" : sha.slice(0, SHORT_SHA);
  return `ERROR: ${PLUGIN} ${scope.name} scope is at ${at}, not ${head.slice(0, SHORT_SHA)}; run ${update} from ${checkout}`;
}

runMain((args) => {
  const [arg, ...rest] = args;
  if (arg === undefined || rest.length > 0)
    throw new CodedError("usage", { usage: USAGE, problem: "takes exactly one checkout" });
  const checkout = resolve(arg);
  const head = headOf(checkout);
  const path = installsPath();
  if (!existsSync(path)) throw new CodedError("installs_missing", { path });
  const installs = readJson(path, Installs).plugins[PLUGIN] ?? [];
  const scopes: readonly Scope[] = [
    { name: "user", install: installs.find((install) => install.scope === "user") ?? null },
    {
      name: "project",
      install:
        installs.find(
          (install) =>
            install.scope === "project" &&
            install.projectPath !== undefined &&
            samePath(install.projectPath, checkout),
        ) ?? null,
    },
  ];
  const problems = scopes.flatMap((scope) => problem(scope, head, checkout) ?? []);
  reportProblems(problems, "run mise run plugin:update, or the update each line names");
  if (problems.length === 0)
    process.stdout.write(`OK: ${PLUGIN} is at ${head.slice(0, SHORT_SHA)} in user and project scope\n`);
});
