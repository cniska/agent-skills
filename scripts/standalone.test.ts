import { describe, expect, test } from "bun:test";
import { readdirSync } from "node:fs";
import { join, relative } from "node:path";

import { ROOT_DIR } from "../lib/paths";
import { readText } from "../lib/read-file";

const GUARDED_DIRS = ["skills", "agents"] as const;
const HOOKS_DIR = "hooks";
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

  test("no hook script names a tool, so none runs its CLI", () => {
    const named = filesUnder(join(ROOT_DIR, HOOKS_DIR))
      .filter((path) => path.endsWith(".sh"))
      .flatMap((path) => toolMentions(relative(ROOT_DIR, path), readText(path)));
    expect(named).toEqual([]);
  });
});
