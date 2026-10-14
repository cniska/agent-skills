import { afterAll, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const CHECK = join(import.meta.dir, "plugin-check.ts");
const TEMP_ROOT = mkdtempSync(join(tmpdir(), "plugin-check-test-"));
const STALE_SHA = "82b6d60520d21525ac0f9e7b6cffd72d4d8b79ae";

type Run = { readonly code: number; readonly stdout: string; readonly stderr: string };
type Entry = { readonly scope: string; readonly projectPath?: string; readonly gitCommitSha?: string };

function git(cwd: string, ...args: readonly string[]): string {
  const result = Bun.spawnSync(
    ["git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "-C", cwd, ...args],
    { env: { PATH: process.env.PATH ?? "" } },
  );
  if (result.exitCode !== 0) throw new Error(result.stderr.toString());
  return result.stdout.toString().trim();
}

function checkout(name: string): { readonly path: string; readonly head: string } {
  const path = join(TEMP_ROOT, name);
  mkdirSync(path);
  git(path, "init", "-q");
  git(path, "commit", "-q", "--allow-empty", "-m", "init");
  return { path, head: git(path, "rev-parse", "HEAD") };
}

function configDir(name: string, entries: readonly Entry[]): string {
  const dir = join(TEMP_ROOT, name);
  mkdirSync(join(dir, "plugins"), { recursive: true });
  const installs = {
    version: 2,
    plugins: {
      "cniska-skills@cniska": entries,
      "other@market": [{ scope: "user", gitCommitSha: STALE_SHA }],
    },
  };
  writeFileSync(join(dir, "plugins", "installed_plugins.json"), JSON.stringify(installs));
  return dir;
}

function check(config: string, ...args: readonly string[]): Run {
  const result = Bun.spawnSync([process.execPath, CHECK, ...args], {
    env: { PATH: process.env.PATH ?? "", HOME: TEMP_ROOT, CLAUDE_CONFIG_DIR: config },
  });
  return { code: result.exitCode, stdout: result.stdout.toString(), stderr: result.stderr.toString() };
}

afterAll(() => rmSync(TEMP_ROOT, { recursive: true, force: true }));

describe("plugin-check", () => {
  const repo = checkout("agent-skills");
  const foreign = checkout("scratch");

  test("passes when both scopes match HEAD and a foreign project install is stale", () => {
    const config = configDir("current", [
      { scope: "user", gitCommitSha: repo.head },
      { scope: "project", projectPath: repo.path, gitCommitSha: repo.head },
      { scope: "project", projectPath: foreign.path, gitCommitSha: STALE_SHA },
      { scope: "project", projectPath: join(TEMP_ROOT, "gone"), gitCommitSha: STALE_SHA },
    ]);
    const run = check(config, repo.path);
    expect(run.stderr).toBe("");
    expect(run.code).toBe(0);
    expect(run.stdout).toBe(
      `OK: cniska-skills@cniska is at ${repo.head.slice(0, 12)} in user and project scope\n`,
    );
  });

  test("fails naming a stale user scope only", () => {
    const config = configDir("stale-user", [
      { scope: "user", gitCommitSha: STALE_SHA },
      { scope: "project", projectPath: repo.path, gitCommitSha: repo.head },
      { scope: "project", projectPath: foreign.path, gitCommitSha: STALE_SHA },
    ]);
    const run = check(config, repo.path);
    expect(run.code).toBe(1);
    expect(run.stdout).toBe("");
    expect(run.stderr).toContain(
      `ERROR: cniska-skills@cniska user scope is at 82b6d60520d2, not ${repo.head.slice(0, 12)}; run claude plugin update cniska-skills@cniska --scope user from ${repo.path}`,
    );
    expect(run.stderr).not.toContain("project scope");
  });

  test("fails naming a stale project scope and one with no recorded commit", () => {
    const config = configDir("stale-project", [
      { scope: "user" },
      { scope: "project", projectPath: repo.path, gitCommitSha: STALE_SHA },
    ]);
    const run = check(config, repo.path);
    expect(run.code).toBe(1);
    expect(run.stderr).toContain("ERROR: cniska-skills@cniska user scope is at no recorded commit");
    expect(run.stderr).toContain("ERROR: cniska-skills@cniska project scope is at 82b6d60520d2");
  });

  test("fails when the checkout has no project-scope install", () => {
    const config = configDir("no-project", [
      { scope: "user", gitCommitSha: repo.head },
      { scope: "project", projectPath: foreign.path, gitCommitSha: foreign.head },
    ]);
    const run = check(config, repo.path);
    expect(run.code).toBe(1);
    expect(run.stderr).toContain(`ERROR: cniska-skills@cniska has no project-scope install for ${repo.path}`);
  });

  test("refuses a missing install record", () => {
    const run = check(join(TEMP_ROOT, "no-config"), repo.path);
    expect(run.code).toBe(1);
    expect(run.stderr).toStartWith(
      `no plugin install record at ${join(TEMP_ROOT, "no-config", "plugins", "installed_plugins.json")}\n`,
    );
  });

  test("refuses a directory that is not a git checkout", () => {
    const path = join(TEMP_ROOT, "plain");
    mkdirSync(path);
    const run = check(configDir("for-plain", []), path);
    expect(run.code).toBe(1);
    expect(run.stderr).toStartWith(`${path} is not a git checkout with a commit:`);
  });

  test("refuses a call without exactly one checkout", () => {
    expect(check(configDir("usage", [])).code).toBe(2);
  });
});
