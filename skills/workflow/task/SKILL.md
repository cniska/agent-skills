---
name: task
description: Run one task along the route its kind needs — feature, bug fix, refactor, test or review — on its own branch, loading each step's skill in order (a feature plans the design, validates it, then builds). Use at the start of any task that changes code or reviews a change, and again to re-enter its route after a host resume or fork. A skill, loaded with the Skill tool; not a host's Task tool.
argument-hint: "<task>"
---

# Task

Run one task so that it lands whole, does what was asked, and is reviewed by an agent that did not write it.

## What matters

- **The route follows what the change is.** Re-route when the task changes kind.
- **One topic branch in your own worktree, kept to the repo's rules and landed whole once done**, so the main branch only ever holds finished work.
- **A fresh agent reviews each commit before you make it**: `design-review` for code, `doc-review` for docs, and `ui-review` with captures for an interface. A fresh agent runs `review` on the whole branch before it lands. When the same work comes back a third time, stop and report what the returns show.
- **Fix what your change causes or what blocks it**, and report other defects as follow-ups, so the change stays one thing.
- **A defect in a tool, hook or gate stops the task.** Report the command and what it printed, so the defect gets fixed at its source.
- **Done is the branch landed with CI green on the landed commit**, then remove its worktree.

## Routes

| Route | When | File |
|---|---|---|
| Feature | New or changed behavior | [references/feature.md](references/feature.md) |
| Bug fix | Behavior that differs from what it should be | [references/bug-fix.md](references/bug-fix.md) |
| Refactor | A change to structure that keeps behavior, a redesign, or a removal | [references/refactor.md](references/refactor.md) |
| Test | A change only to tests, or to the spec wording they prove | [references/test.md](references/test.md) |
| Review | Someone else's change, or a change that already landed | [references/review.md](references/review.md) |

In the routes, Open loads a writing skill before the first edit to each type of file: `code-writing` for code, `skill-writing` for a skill or agent definition, `agents-md` for a rules file and `docs-writing` for any other doc. Challenge is a `second-opinion` on a design you proposed, and Close is the reviews above, then landing.

## Report

Lead with the outcome, then what needs the owner, each choice you made for them, the follow-ups, and the landed commit with its CI runs.
