import { describe, expect, test } from "bun:test";
import { readdirSync } from "node:fs";
import { join, relative } from "node:path";

import { ROOT_DIR } from "../lib/paths";
import { readText } from "../lib/read-file";

const GUARDED_DIRS = ["skills", "agents"] as const;
const HOOKS_DIR = "hooks";
const COORDINATOR_HOOK_FILES = new Set(["hooks/coordinator.sh", "hooks/coordinator.test.sh"]);
const TOOL = /\b(?:agent|cniska)-(?:record|gates|worktree|task)\b/;

function filesUnder(dir: string): readonly string[] {
  return readdirSync(dir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => join(entry.parentPath, entry.name));
}

function toolMentions(path: string, text: string): readonly string[] {
  return text.split("\n").flatMap((line, index) => (TOOL.test(line) ? [`${path}:${index + 1}`] : []));
}

describe("cniska-skills requires no other tool", () => {
  test("no skill or agent definition names a tool", () => {
    const named = GUARDED_DIRS.flatMap((dir) =>
      filesUnder(join(ROOT_DIR, dir)).flatMap((path) =>
        toolMentions(relative(ROOT_DIR, path), readText(path)),
      ),
    );
    expect(named).toEqual([]);
  });

  test("no hook script but the coordinator hook names a tool, so only a coordinating session runs one", () => {
    const named = filesUnder(join(ROOT_DIR, HOOKS_DIR))
      .filter((path) => path.endsWith(".sh"))
      .map((path) => relative(ROOT_DIR, path))
      .filter((path) => !COORDINATOR_HOOK_FILES.has(path))
      .flatMap((path) => toolMentions(path, readText(join(ROOT_DIR, path))));
    expect(named).toEqual([]);
  });

  test("the coordinator hook stays silent in a session started without a project", () => {
    const run = Bun.spawnSync([join(ROOT_DIR, "hooks", "coordinator.sh")], {
      env: { PATH: "/usr/bin:/bin" },
      stdin: "ignore",
    });
    expect([run.exitCode, run.stdout.toString(), run.stderr.toString()]).toEqual([0, "", ""]);
  });
});
