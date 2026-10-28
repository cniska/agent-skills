---
name: build
description: Implement a feature slice by slice, deciding how the work is cut and ordered and when a run of slices stops and hands back. Use when implementing a feature that takes more than one commit, when picking up work a brief or plan has already sliced, or when slices run unattended.
---

# Build

This skill makes two calls: how the work is cut into slices, and when a run of them stops. Everything else a slice goes through belongs to the route the task runs or to the repo's own rules: each slice is written and verified as `code-writing` says, and is accepted by `design-review`, or `doc-review` on docs, and by `ui-review` when it changes an interface, and committed as `git` says before the next one starts.

## Cut the slices

A brief or a plan that already slices the work is the input, not a reason to skip this skill: take its slices in the order given, and keep the stop rules below. Otherwise cut the work yourself:

- **Vertical**, the default: one whole path through the stack, with its type, its implementation and its test.
- **Contract-first**: the schema and types land first, then each consumer as a slice of its own.
- **Risk-first**: the uncertain part goes first, so the plain parts build on something proven.

A slice is a path, never a layer. Good: `POST /orders`, the form that calls it, and one test. Bad: every endpoint, then every screen, then every test.

## Stop and hand back

A run takes slice after slice with no reader in between, and its scope stays with whoever set it. Stop, and hand back to whoever coordinates the run, or else the owner, when:

- the next slice needs a change the brief or plan does not cover
- one slice has failed verification twice, since a third try is a guess
- a fix reaches a file or contract outside the plan's boundary
- the right behavior is unclear and nobody is there to ask

Name what stopped the run and which slices were committed. The per-slice commits are the record; keep no progress log beside them.

## See also

- `plan` — the scope and slices a run takes as its input
- `tdd` — red-green-refactor inside a slice of crucial logic
- `code-writing` — how each slice's code is written and verified
- `simplify` — cutting complexity from code that works, without changing what it does
- `design-review` and `doc-review` — the reviews each slice waits on, on code and on docs
- `ui-review` — the review a slice that changes an interface also waits on
- `git` — how each slice is committed

## Red flags

- Skipping this skill because a brief or plan already sliced the work
- A slice that is one layer of the stack rather than one path through it
- Reordering, merging or splitting a brief's slices without saying why
- Starting the next slice before the last one is accepted and committed
- Widening the plan mid-run instead of stopping to hand back
- A third attempt at a slice that already failed verification twice
- A progress log kept beside the per-slice commits
