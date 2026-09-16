---
name: deprecation
description: Deprecate and remove code safely. Use when replacing systems, removing unused features, or consolidating duplicate implementations.
---

# Deprecation

Code is a liability: every line costs maintenance, so when equivalent functionality needs less code or a better abstraction, retire the old version. Hyrum's Law makes that hard — every observable behavior, bugs included, has a dependent — so deprecation is active migration, not an announcement. No transitional architecture: land the replacement, migrate consumers, remove the old system rather than running two in parallel. If you own the infrastructure being deprecated, migrating its users is your job.

## Workflow

1. **Build the replacement first.** Never deprecate without a working alternative.
2. **Identify all consumers.** Grep for usages, check imports, trace call paths.
3. **Migrate incrementally.** Move consumers one at a time, verify each migration.
4. **Verify zero usage.** Confirm no remaining references before removing.
5. **Remove completely.** Delete code, tests, documentation, configuration. No commented-out remnants.

## Zombie code

Code with no owner but active dependents — stale for months, failing tests left unfixed, outdated dependencies. Assign an owner or deprecate it with a migration plan; it cannot stay suspended.

## Red flags

- Deprecating without a replacement available
- Multi-month "soft" deprecations with no progress
- New features added to deprecated systems
- Code removal without verifying zero active consumers
- "We'll maintain both indefinitely"
