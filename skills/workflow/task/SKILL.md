---
name: task
description: Run one task along the route its kind needs — feature, bug fix, refactor, test or review — on its own branch, loading each step's skill in order (a feature plans the design, validates it, then builds). Use at the start of any task that changes code or reviews a change, and again to re-enter its route after a host resume or fork. A skill, loaded with the Skill tool; not a host's Task tool.
argument-hint: "<task>"
---

# Task

Run one task so that it lands whole, reviewed by someone who did not write it, and does what was asked. Each step serves the task: ask what it needs from the step before following any rule here.

## Rules

1. **Read the repo's rules first**, such as its `AGENTS.md` or `CLAUDE.md`. They decide branch names, commit style and how work lands.
2. **Work on a topic branch in your own worktree**, and land the branch whole once it is done, never slice by slice.
3. **Choose the route from what the code change is, not how the request is worded**, and use each step's skill as you reach that step. A change to a skill goes through `skill-writing`, and a doc edit through `docs-writing`. Re-route when the task changes kind.
4. **Have a fresh agent review each commit before you make it**: `design-review` for code, `doc-review` for docs, and `ui-review` with captures for an interface. Before the branch lands, a fresh agent runs `review` on the whole branch. Fix every finding. If the same work comes back a third time, stop and report what the returns show.
5. **Fix what your change causes or what blocks it.** Report other real defects as follow-ups, without fixing them.
6. **Stop at a defect in a tool, hook or gate**, and report it with the command and what it printed. Never reword a command or reshape a change to get past one.
7. **The task is done once the branch has landed and CI on the landed commit is green.** Then remove the worktree.

## Routes

| Route | When | File |
|---|---|---|
| Feature | New or changed behavior | [references/feature.md](references/feature.md) |
| Bug fix | Behavior that differs from what it should be | [references/bug-fix.md](references/bug-fix.md) |
| Refactor | A change to structure that keeps behavior, a redesign, or a removal | [references/refactor.md](references/refactor.md) |
| Test | A change only to tests, or to the spec wording they prove | [references/test.md](references/test.md) |
| Review | Someone else's change, or a change that already landed | [references/review.md](references/review.md) |

Each route's steps:
- **Open** means start in your worktree, loading `code-writing` before the first edit.
- **Challenge** means getting a `second-opinion` on a design you proposed.
- **Close** means rule 4's reviews, then landing, as rules 4 and 7 say.

## Resume

After a host resume or fork, load this skill again. Rebuild where the task stands from the checkout, using `git worktree list`, `git status` and `git log`, then go on from that step.

## Report

Lead with the outcome. Then give what needs the owner's decision, each choice you made that the owner did not ask for, the follow-ups, and the landed commit with its CI runs.

## See also

- `coordinate`: runs work across several agents, each task through this skill
- `principles`: the review report every reviewer fills
