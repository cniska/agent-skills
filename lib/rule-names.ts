import { existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { readText } from "./read-file";

type RulePick =
  | { readonly kind: "headings"; readonly level: number }
  | { readonly kind: "bold_leads" }
  | { readonly kind: "title" };

export type RuleSource = {
  readonly path: string;
  readonly pick: RulePick;
  readonly under?: readonly string[];
  readonly except?: readonly string[];
};

export type RuleName = { readonly name: string; readonly sources: readonly string[] };

export type RuleNames = { readonly names: readonly RuleName[]; readonly problems: readonly string[] };

export const RULE_NAMES_FILE = "hooks/rule-names.json";

const SECTIONS = { kind: "headings", level: 2 } as const;
const SCOPE_BUCKETS = { pick: { kind: "headings", level: 3 }, under: ["Scope"] } as const;
const BOLD_LEADS = { kind: "bold_leads" } as const;

export const RULE_SOURCES: readonly RuleSource[] = [
  {
    path: "skills/expertise/design-review/references/patterns.md",
    pick: SECTIONS,
    under: ["Architecture", "Code"],
  },
  { path: "skills/expertise/design-review/references/api.md", pick: SECTIONS },
  { path: "skills/expertise/design-review/references/agent.md", pick: BOLD_LEADS },
  { path: "skills/expertise/design-review/references/ui.md", pick: BOLD_LEADS },
  { path: "skills/expertise/principles/references", pick: { kind: "title" }, except: ["Review report"] },
  { path: "skills/expertise/doc-review/SKILL.md", ...SCOPE_BUCKETS },
  { path: "skills/expertise/correctness-review/SKILL.md", ...SCOPE_BUCKETS },
  { path: "skills/expertise/test-review/SKILL.md", ...SCOPE_BUCKETS },
  { path: "skills/expertise/security-review/SKILL.md", ...SCOPE_BUCKETS },
  { path: "skills/expertise/performance-review/SKILL.md", ...SCOPE_BUCKETS },
  { path: "skills/expertise/maintainability-review/SKILL.md", ...SCOPE_BUCKETS },
  { path: "skills/expertise/architecture-review/SKILL.md", ...SCOPE_BUCKETS },
  { path: "skills/expertise/doc-review/references/patterns.md", pick: SECTIONS },
  { path: "skills/expertise/ui-design/SKILL.md", pick: SECTIONS, except: ["Review gate"] },
  { path: "skills/expertise/ui-design/references", pick: SECTIONS, except: ["Proof", "Where to look"] },
  { path: "skills/expertise/ui-review/references/heuristics.md", pick: SECTIONS },
  {
    path: "skills/workflow/spec/SKILL.md",
    pick: SECTIONS,
    except: ["Workflow", "Editing an existing spec"],
  },
  { path: "agents/reviewer.md", pick: BOLD_LEADS, under: ["A brief or plan"] },
  {
    path: "skills/expertise/principles/references/review-report.md",
    pick: BOLD_LEADS,
    under: ["Rule names"],
  },
];

const HEADING = /^(?<marks>#{1,6})\s+(?<title>.+?)\s*$/;
const FENCE = /^\s*(```|~~~)/;
const BOLD_LEAD = /^- \*\*(?<lead>.+?)\*\*/;
const NUMBERED = /^\d+\.\s+/;
const TRAILING_MARK = /[.,:;]+$/;

type Line =
  | { readonly kind: "heading"; readonly level: number; readonly heading: string }
  | { readonly kind: "text"; readonly text: string };

function line(raw: string): Line {
  const groups = HEADING.exec(raw)?.groups;
  if (groups?.marks === undefined || groups.title === undefined) return { kind: "text", text: raw };
  return { kind: "heading", level: groups.marks.length, heading: groups.title.replace(NUMBERED, "") };
}

function lines(text: string): Line[] {
  let fenced = false;
  return text.split("\n").flatMap((raw) => {
    if (FENCE.test(raw)) {
      fenced = !fenced;
      return [];
    }
    return fenced ? [] : [line(raw)];
  });
}

function sectionsUnder(all: readonly Line[], parents: readonly string[] | undefined): Line[][] {
  if (parents === undefined) return [[...all]];
  const sections: Line[][] = [];
  let open: { readonly level: number; readonly lines: Line[] } | null = null;
  for (const each of all) {
    if (each.kind === "heading" && open !== null && each.level <= open.level) {
      sections.push(open.lines);
      open = null;
    }
    if (each.kind === "heading" && parents.includes(each.heading)) {
      open = { level: each.level, lines: [] };
      continue;
    }
    open?.lines.push(each);
  }
  if (open !== null) sections.push(open.lines);
  return sections;
}

function headingsAt(section: readonly Line[], level: number): string[] {
  return section.flatMap((each) => (each.kind === "heading" && each.level === level ? [each.heading] : []));
}

function boldLeads(section: readonly Line[]): string[] {
  return section.flatMap((each) => {
    const lead = each.kind === "text" ? BOLD_LEAD.exec(each.text)?.groups?.lead : undefined;
    return lead === undefined ? [] : [lead.replace(TRAILING_MARK, "")];
  });
}

function picked(section: readonly Line[], pick: RulePick): string[] {
  switch (pick.kind) {
    case "headings":
      return headingsAt(section, pick.level);
    case "title":
      return headingsAt(section, 1).slice(0, 1);
    case "bold_leads":
      return boldLeads(section);
  }
}

function sourceFiles(root: string, path: string): string[] {
  const full = join(root, path);
  if (!existsSync(full)) return [];
  if (!statSync(full).isDirectory()) return [path];
  return readdirSync(full)
    .filter((entry) => entry.endsWith(".md"))
    .sort()
    .map((entry) => `${path}/${entry}`);
}

function headingsOf(all: readonly Line[]): Set<string> {
  return new Set(all.flatMap((each) => (each.kind === "heading" ? [each.heading] : [])));
}

function fromSource(root: string, source: RuleSource): { names: [string, string][]; problems: string[] } {
  const files = sourceFiles(root, source.path);
  if (files.length === 0) return { names: [], problems: [`${source.path}: no rule source at this path`] };
  const except = new Set(source.except ?? []);
  const seen = new Set<string>();
  const names: [string, string][] = [];
  for (const file of files) {
    const all = lines(readText(join(root, file)));
    for (const heading of headingsOf(all)) seen.add(heading);
    for (const section of sectionsUnder(all, source.under))
      for (const name of picked(section, source.pick)) if (!except.has(name)) names.push([name, file]);
  }
  const named = [...(source.under ?? []), ...except];
  const problems = named
    .filter((heading) => !seen.has(heading))
    .map((heading) => `${source.path}: no heading "${heading}" for the rule names to read`);
  if (names.length === 0) problems.push(`${source.path}: gives no rule name`);
  return { names, problems };
}

export function ruleNames(root: string, sources: readonly RuleSource[] = RULE_SOURCES): RuleNames {
  const byName = new Map<string, Set<string>>();
  const problems: string[] = [];
  for (const source of sources) {
    const found = fromSource(root, source);
    problems.push(...found.problems);
    for (const [name, file] of found.names) byName.set(name, (byName.get(name) ?? new Set()).add(file));
  }
  const names = [...byName.entries()]
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([name, files]) => ({ name, sources: [...files].sort() }));
  return { names, problems };
}

export function ruleNamesJson(names: readonly RuleName[]): string {
  return `${JSON.stringify({ names }, null, 2)}\n`;
}
