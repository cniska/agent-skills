---
name: task
description: Run one task on its own branch along the route its kind needs — feature, bug fix, refactor, test or review — loading each step's skill in order, so a feature plans the design, validates it, then builds it. Use at the start of any task that changes code or reviews a change, and again to re-enter its route after a host resume or fork. It is a skill loaded with the Skill tool, not a host's Task tool.
---

# Task

Run one task so that it lands whole, does what was asked, and is reviewed by an agent that did not write it.

## What matters

- **The route follows what the change is.** Re-route when the task changes kind.
- **One topic branch in your own worktree, kept to the repo's rules and landed whole once done**, so the main branch only ever holds finished work.
- **An agent that did not write the change reviews each commit before you make it**: `design-review` for code, `doc-review` for docs, and `ui-review` with captures for an interface. Before the branch lands, another such agent runs `review` on the whole branch.
  - **Fixes:** fix a commit review's return whose findings are all minor, with no conflict, and commit it without another round. Send the fix of any other return, every return of the branch's `review` included, to the agent that returned it through `SendMessage`, then wait for its verdict without handing back, since the task is still yours.
  - **One agent per review:** the commit's reviewer, its designer and the branch's `review` each keep one agent across their rounds, since it already holds what it read. Brief a new agent with the earlier returns and the fix only when that one can no longer be reached, as after a session restart.
  - **Cap:** a review stops once `gate.returns` in its agent's stored report, which counts the returns since that agent's last accept, reaches 3: `any_severity` for the branch's `review`, `critical_or_major` for every other. Fix nothing more and report the returns to your coordinator, or to the owner in a task a coordinator runs itself or with no coordinator, since no one rules on a change they wrote.
  - **Ruling:** do what the ruling that comes back says: `coordinate` says how a coordinator rules, and the plugin's `docs/plugin.md` under Rulings what each ruling does in the gate. Pass each ruling to the branch's reviewer in its brief, and take any conflict it reports with one back to whoever ruled before you land.
  - **The owner's words:** in a top-level session, record the owner's direct instruction to commit, or their decision on a stop, through the report server's `ruling` tool with their words. A worker reports them to its coordinator.
- **Before asking for each review, sweep for drift** as no drift in `principles` says, since drift is what reviews return most often.
- **Fix what your change causes or what blocks it**, and report other defects as follow-ups, so the change stays one thing.
- **A defect in a tool, hook or gate stops the task.** Report the command and what it printed, so the defect gets fixed at its source.
- **Done is the branch landed with CI green on the landed commit**, then remove its worktree.
- **Wait on a long run in steps shorter than the host's prompt-cache lifetime**, so resuming after each step reads the context from the cache instead of writing it there again.

## Routes

| Route | When | File |
|---|---|---|
| Feature | New or changed behavior | [references/feature.md](references/feature.md) |
| Bug fix | Behavior that differs from what it should be | [references/bug-fix.md](references/bug-fix.md) |
| Refactor | A change to structure that keeps behavior, a redesign, or a removal | [references/refactor.md](references/refactor.md) |
| Test | A change only to tests, or to the spec wording they prove | [references/test.md](references/test.md) |
| Review | Someone else's change, or a change that already landed | [references/review.md](references/review.md) |

In the routes, Open loads a writing skill before the first edit to each type of file: `code-writing` for code, `skill-writing` for a skill or agent definition, `rules-writing` for a rules file and `docs-writing` for any other doc. Challenge has a reviewer judge a design you proposed against `design-review`, counted and capped like any review, and Close is the reviews above, then landing.

## Report

Lead with the outcome, then what needs the owner, each choice you made for them, the follow-ups, and the landed commit with its CI runs.
