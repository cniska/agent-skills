---
name: deprecation
description: Deprecate and remove code safely. Use when replacing systems, removing unused features, or consolidating duplicate implementations.
---

# Deprecation

Code is a liability: every line costs maintenance, so when equivalent functionality needs less code or a better abstraction, retire the old version. Hyrum's Law makes that hard — every observable behavior, bugs included, has a dependent — so deprecation is active migration, not an announcement. No transitional architecture: land the replacement, migrate consumers, remove the old system rather than running two in parallel.

**Whether you can reach every consumer decides the path.** Inside a codebase you own, grep is exhaustive and removal is one change. Across a boundary you don't — a published package, a shared schema, an API other teams call — removal is gated on a major version: annotate it deprecated, ship the migration note, delete on the next major. There the announcement *is* the work product, and a deprecation sitting unremoved for months is correct rather than stalled.

## Workflow

1. **Find every consumer.** Grep usages, imports and call paths — then the places code doesn't live: docs and install instructions, CI config, build files, manifests and lockfiles. Their reach decides which path above you are on.
2. **Have the replacement working** before anything comes out. Where nothing is being replaced — a dependency that was never needed, a code path with no callers — there is no replacement to build, and this step is done.
3. **Migrate consumers**, verifying each.
4. **Verify zero usage.** Confirm no remaining references before removing. Where a static check can't prove it, say which check you ran.
5. **Remove completely.** Delete code, tests, documentation, configuration. No commented-out remnants.

## See also

- `build` — migrate consumers one verified slice at a time
- `architecture-review` — find the coupling that makes a consumer hard to migrate

## Red flags

- Removing something whose replacement doesn't exist yet
- A deprecation with nothing gating its removal — no version, no date, no owner
- New features added to deprecated systems
- Code removal without verifying zero active consumers
- "We'll maintain both indefinitely"
