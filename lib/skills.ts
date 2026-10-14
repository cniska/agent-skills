import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

export const SKILL_KINDS = ["workflow", "expertise"] as const;

export type SkillKind = (typeof SKILL_KINDS)[number];

export const SKILL_KIND_RULES: { readonly [Kind in SkillKind]: string } = {
  workflow: "steps that produce an output",
  expertise: "rules for what good looks like in one kind of work",
};

export type SkillDir = { readonly name: string; readonly kind: SkillKind; readonly dir: string };

function subdirectories(dir: string): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

export function skillDirs(skillsDir: string): SkillDir[] {
  return SKILL_KINDS.flatMap((kind) =>
    subdirectories(join(skillsDir, kind)).map((name) => ({ name, kind, dir: join(skillsDir, kind, name) })),
  );
}

export function strayEntries(skillsDir: string): string[] {
  const kinds = new Set<string>(SKILL_KINDS);
  return readdirSync(skillsDir)
    .filter((entry) => !kinds.has(entry) && !entry.startsWith("."))
    .sort();
}
