---
name: rules-writing
description: Create or update a repo's AGENTS.md, the cross-tool rules every coding agent follows there: a new file holds only rules inferred from the code, and each change merges into the file without repeating what it already says. Use when writing a project's rules file for the first time, or adding, changing or trimming a rule in one.
---

# Rules writing

`AGENTS.md` holds a repo's cross-tool rules: the conventions any coding agent follows there. Every agent loads it on every task, so it holds what each task needs and points to the rest. A tool that reads its own memory file instead, such as Claude Code's `CLAUDE.md`, gets a one-line import of `AGENTS.md` plus any rule only that tool needs. Harness settings, such as Claude Code's `settings.json`, are tool config, not project rules.

## What matters

- **Each rule lives in `AGENTS.md` once**, not spread across the memory files that import it.
- **A rule that lasts:** apply `writing`'s rules for documents that last, so the file states the rule and not its history, and word each rule as `writing` says for instructions an agent follows.
- **One rule per bullet,** each bullet or paragraph on one line, left to soft-wrap, since a hard-wrapped line breaks the diff of every later edit.
- **The file's own words.** Reuse the vocabulary the file already uses for a concept.
- **Lean.** A new rule grows the file only when no existing bullet can absorb it.
- **Placement by cost.** Each line costs tokens on every task. Weigh how often a fact is needed against that cost, and keep it inline or behind a one-line pointer to a doc or an executable. The split differs per project, so apply the principle rather than a line count or a section recipe. When the file must shrink, cut first what an agent could re-derive, such as a list it could read off a manifest.
- **The lowest layer that still reaches the work:** machine-wide guidance, this repo, a skill, a doc or an executable gate. Keep judgment in prose, and make a mechanical invariant a check where the project can run one.
- **A no comments bullet,** stating the rule from `principles` for new and changed code, where the code rules live. Where the project can run a check, one that scans the lines a diff adds holds it, since a whole-tree scan fails on every existing comment.
- **The spec first.** When a `SPEC.md` exists, the opening line names it as the source of truth for requirements and requires keeping it current in the change that changes behavior. Invariants, code and unit test names describe behavior in plain terms, since a spec ID there goes stale when the spec renumbers. Acceptance test names cite criteria, as `spec` says.

## Modes

- **Create**, when no `AGENTS.md` exists at the target: infer the rules from evidence, as [create](references/create.md) says.
- **Update**, when one exists: merge each new rule into the right section and trim what it duplicates, as [update](references/update.md) says. Updating is the harder half, since an appended rule grows the file and repeats what it already says.
