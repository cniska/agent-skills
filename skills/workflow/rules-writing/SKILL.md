---
name: rules-writing
description: Create and update AGENTS.md project rules. Use when authoring or amending the cross-tool conventions agents must follow.
---

# Rules writing

`AGENTS.md` holds the cross-tool project rules — the conventions any coding agent must follow in this repo.

Not the same as adjacent artifacts — keep them distinct:

- `CLAUDE.md` and `/init` are Claude Code's own memory, not the cross-tool rulebook. A tool that reads its own memory file instead of `AGENTS.md` gets a one-line import pointing at it (plus any tool-only overrides), never a second copy of the rules.
- `settings.json` is harness config (the `update-config` skill), not project conventions.

When a rule belongs in AGENTS.md, put it there — don't scatter the same rule across these files.

## Conventions this file must follow (and enforce)

- Apply `writing`'s rules for documents that last: a rule, not its history; each fact in one place.
- Word each rule as `writing`'s medium for instructions an agent follows says.
- One logical rule per bullet.
- Never hard-wrap markdown — one line per bullet or paragraph, let it soft-wrap.
- Reuse the existing file's vocabulary — don't coin a synonym for a concept already named.
- Keep it lean — prefer trimming to growing. A new rule shouldn't grow the file if an existing bullet can absorb it.
- Decide placement by cost, not by recipe. AGENTS.md is loaded on every task, so every line pays a recurring token cost. Whether a fact belongs inline here or behind a one-line pointer to a doc or executable is a judgment: weigh how often it's needed against that per-task cost, and decide for this project. The right split differs across projects and shifts as models improve — apply the principle rather than a fixed line count or section recipe. When the file must come down, cut what is cheapest to re-derive — an enumeration the agent could read off a manifest — before anything a reader could not reconstruct from the repo at all.
- Put a rule in the lowest layer that still reaches the work: machine-wide guidance, this repo, a skill, a doc, or an executable gate. Keep judgment in prose; make mechanical invariants executable where the project can enforce them.
- Always carry a comment ban — one bullet stating no comments from `principles`. Scope it to new and changed code, so it states the convention going forward rather than a claim about the tree. Where the project can run one, a check that scans the lines a diff adds holds it; a whole-tree scan would fail on every existing comment. Put it where code rules already live.
- If a `SPEC.md` exists, the opening line must reference it as the source of truth for requirements and require keeping it current in the same change that changes behavior — the spec never lags the code. Invariants, code and unit test names cite no spec ID, since renumbering would leave them stale — describe behavior in plain terms; acceptance test names cite criteria, as `spec` says, and the spec is the reference for why.

## Modes

- **Create**, when no `AGENTS.md` exists at the target: infer the rules from evidence, as [create](references/create.md) says.
- **Update**, when one exists: merge each new rule into the right section and trim what it duplicates, as [update](references/update.md) says. Updating is the harder half, since a blind append grows the file and repeats what it already says.
