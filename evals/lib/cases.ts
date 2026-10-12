import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";
import { CodedError } from "./coded-error";
import { readFrontmatter } from "./frontmatter";

export const EVALS_DIR = join(import.meta.dir, "..");

export type EvalCase = { readonly name: string; readonly dir: string; readonly tags: readonly string[] };

const PromptFrontmatter = z.looseObject({ tags: z.array(z.string()).optional() });

function isCase(dir: string): boolean {
  return existsSync(join(dir, "prompt.md")) || existsSync(join(dir, "case.yaml"));
}

function caseTags(dir: string): readonly string[] {
  const prompt = join(dir, "prompt.md");
  if (!existsSync(prompt)) return [];
  const parsed = PromptFrontmatter.safeParse(readFrontmatter(prompt));
  if (!parsed.success) {
    throw new CodedError("input-invalid", {
      path: prompt,
      problem: "tags must be an inline list, such as tags: [git]",
    });
  }
  return parsed.data.tags ?? [];
}

export function cases(): EvalCase[] {
  return readdirSync(EVALS_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && isCase(join(EVALS_DIR, entry.name)))
    .map((entry) => {
      const dir = join(EVALS_DIR, entry.name);
      return { name: entry.name, dir, tags: caseTags(dir) };
    });
}
