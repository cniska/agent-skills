---
name: task
description: Run one task along the route its kind needs — feature, bug fix, refactor, test or review — loading each step's skill in order. Use at the start of any task that changes code or reviews a change, and again to resume one after context compaction. A skill, loaded with the Skill tool; not a host's Task tool.
argument-hint: "<task>"
---

# Task

A skill runs only when something loads it, and this one is a skill: load it with the Skill tool, never through a host tool named Task. Pick the task's route and work through its steps, loading each step's skill when the step starts. A route names skills; each skill owns how its step is done.

## Pick the route

1. **Read the request and the repo's `AGENTS.md` or `CLAUDE.md`.** The repo's rules win over any step: how it branches, checks and lands. Push or land each accepted commit, as the repo says, before starting the next, so a return strands no commit stacked on one not yet accepted. Where landing waits on the owner's approval, keep going: stack the next accepted commit on the same branch or pull request, and the owner approves the stack. Where the repo lands each commit once accepted, `review` runs on the whole change after the last one lands. A repo skill that covers the task or a step takes its place.
2. **Match the route by what the task changes**, read from the code it names, not by its wording. A code change always has a route. A change to a skill or agent goes through `skill-writing`, then the per-commit step, `design-review` by a fresh agent, and landing. A task that changes no code, such as a question or a doc edit, goes straight to its own skill.
3. **Load each step's skill with the Skill tool when the step starts**: this set's skill, not a host skill or tool that shares its name. Skip a step only when its work does not arise, such as `second-opinion` on a design the owner's brief decided rather than one the agent proposed, or one already challenged; a change that looks small still takes every step its work reaches.
4. **`design-review` runs in a fresh agent that did not write the work**, briefed with the diff or design in a file it reads, and every decision the owner settled, a plan included. A return's Fix findings are all fixed and re-reviewed until accept; the re-review judges only the fix, for `review` as for `design-review`: the whole-change review stands, and a finding it raises about other code starts its own fix without holding back the accept. On how the code is built, `design-review` wins over other reviewers; any other disagreement, such as a finding that clashes with a settled decision, goes to the owner as a conflict, not a Fix.
5. **Re-route when the task changes kind**, and say so.
6. **Fix every finding in reach rather than filing it**: an accept's Consider findings and neighboring code each land in their own commit, through the same commit steps. Another agent's work on the owner's machine is in reach. Only an owner decision, or a change another person owns, goes to the report. Scope decides where a fix lands, inside the change or in its own commit or branch started at once, never whether it lands.
7. **Resume where the work stands** after context compaction, or when a session picks up earlier work: load `task` again, rebuild the route and step from the ledger where one exists, or else from the checkout (`git worktree list`, `git status`, `git log`), then load the current step's skill, and `code-writing` before any further edit. A plan that lives only in a message goes to the repo or the ledger first.

## Report

- Outcome first, then what needs the owner's decision; the rest in short bullets.
- A working agent sends owner questions to whoever coordinates it and goes on with work that does not depend on them.
- Name the route, and every step skipped or not yet run.
- Several asks in one request: answer each by name, so none is dropped.
- After changes, name every choice the owner did not ask for.

## Routes

| Route | When | File |
|---|---|---|
| Feature | New or changed behavior | [references/feature.md](references/feature.md) |
| Bug fix | Behavior that differs from what it should be | [references/bug-fix.md](references/bug-fix.md) |
| Refactor | A change to structure that keeps behavior, a redesign, or a removal | [references/refactor.md](references/refactor.md) |
| Test | A change only to tests, or to the spec wording they prove | [references/test.md](references/test.md) |
| Review | Someone else's change, or a change that already landed | [references/review.md](references/review.md) |

## See also

- `design-review` — the judgment every route's commits wait on
- `coordinate` — run work across several agents or repos, each task delegated to this skill

## Red flags

- A code edit made outside a route
- Skipping a step because the change looks small
- The session that wrote a change running its `design-review`
- Landing past a repo rule that asks the owner first
- A return left partly fixed, or review stopped before an accept
- A fixable finding left in the report or a backlog
