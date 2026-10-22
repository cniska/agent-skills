#!/usr/bin/env bash
set -euo pipefail

mkdir -p src tests fixtures

cat >package.json <<'JSON'
{
  "name": "notebook",
  "private": true,
  "type": "module",
  "scripts": { "test": "bun test" }
}
JSON

cat >src/config.ts <<'TS'
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export type Config = { readonly theme: "light" | "dark" };

export function writeConfig(dir: string, config: Config): void {
  writeFileSync(join(dir, "config.json"), JSON.stringify(config));
}

export function readConfig(dir: string): Config {
  return JSON.parse(readFileSync(join(dir, "config.json"), "utf8"));
}
TS

cat >fixtures/scratch.ts <<'TS'
import { afterEach } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const made: string[] = [];

afterEach(() => {
  for (const dir of made.splice(0)) rmSync(dir, { recursive: true, force: true });
});

export function scratchDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "notebook-"));
  made.push(dir);
  return dir;
}
TS

mkdir -p tests/settings
cat >tests/settings/config.test.ts <<'TS'
import { expect, test } from "bun:test";
import { scratchDir } from "../../fixtures/scratch";
import { readConfig, writeConfig } from "../../src/config";

test("reads back the written config", () => {
  const dir = scratchDir();
  writeConfig(dir, { theme: "dark" });
  expect(readConfig(dir)).toEqual({ theme: "dark" });
});
TS

git() { command git -c user.name=Owner -c user.email=owner@example.com "$@"; }
git init -q -b main
git add -A
git commit -q -m "feat: read and write config"

cat >src/export.ts <<'TS'
import { writeFileSync } from "node:fs";
import { join } from "node:path";

export type Note = { readonly title: string; readonly body: string };

export function exportNotes(dir: string, notes: readonly Note[]): string {
  const path = join(dir, "export.md");
  writeFileSync(path, notes.map((note) => `# ${note.title}\n\n${note.body}\n`).join("\n"));
  return path;
}
TS

cat >tests/export.test.ts <<'TS'
import { afterEach, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { exportNotes } from "../src/export";

let dirs: string[] = [];

function freshDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "export-"));
  dirs.push(dir);
  return dir;
}

afterEach(() => {
  for (const dir of dirs) rmSync(dir, { recursive: true, force: true });
  dirs = [];
});

test("exports every note under its title", () => {
  const path = exportNotes(freshDir(), [
    { title: "groceries", body: "milk" },
    { title: "todo", body: "call mom" },
  ]);
  const text = readFileSync(path, "utf8");
  expect(text).toContain("# groceries\n\nmilk");
  expect(text).toContain("# todo\n\ncall mom");
});
TS
