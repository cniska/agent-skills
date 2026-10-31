---
name: build
description: Implement a feature slice by slice, deciding how the work is cut and ordered and when a run of slices stops and hands back. Use when implementing a feature that takes more than one commit, when picking up work a brief or plan has already sliced, or when slices run unattended.
---

# Build

Make two calls for a feature: how the work is cut into slices, and when a run of slices stops. Each slice goes through the route's writing, review and commit steps before the next one starts.

## Cut the slices

When a brief or plan already slices the work, take its slices in the order given and keep the stop rules below. Otherwise cut the work in one of these ways:

- **Vertical**, the default: one whole path through the stack, with its type, its implementation and its test.
- **Contract-first**: the schema and types land first, then each consumer as a slice of its own.
- **Risk-first**: the uncertain part goes first, so the plain parts build on something proven.

A slice is one path through the stack, such as `POST /orders`, the form that calls it, and one test. Cutting by layer, every endpoint and then every screen, leaves nothing working until the last slice.

## Stop and hand back

A run takes slice after slice with no reader in between, and its scope stays with whoever set it. Stop and hand back to whoever coordinates the run, or else to the owner, when:

- the next slice needs a change the brief or plan does not cover
- one slice has failed verification twice, since a third try is a guess
- a fix reaches a file or contract outside the plan's boundary
- the right behavior is unclear and nobody is there to ask

Name what stopped the run and which slices were committed. The per-slice commits are the run's record.
