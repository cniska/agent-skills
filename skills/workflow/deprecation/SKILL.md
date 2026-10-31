---
name: deprecation
description: Deprecate code, a dependency or an interface by finding every consumer, migrating each to the replacement and removing the old path completely. Use when replacing a system, removing an unused feature or dependency, or consolidating duplicate implementations.
---

# Deprecation

Retire old code once equivalent functionality needs less code or a better abstraction, since every line costs maintenance. Hyrum's Law makes that hard: every observable behavior, bugs included, has a dependent. So deprecation is active migration, finished when the old path is gone, as no transitional architecture in `principles` says.

**Whether you can reach every consumer decides the path.** Inside a codebase you own, a search finds every use, and removal is one change. Across a boundary you don't own, such as a published package, a shared schema or an API other teams call, removal waits for a major version: mark the old path deprecated, ship the migration note, and delete it in the next major. There the announcement is the work product, and a deprecation that sits unremoved for months is on schedule.

## Workflow

1. **Find every consumer.** Search usages, imports and call paths, then the places code doesn't live: docs and install instructions, CI config, build files, manifests and lockfiles. Their reach decides the path above.
2. **Have the replacement working** before anything comes out. When nothing replaces the old code, such as a dependency that was never needed or a code path with no callers, this step is done.
3. **Migrate the consumers**, verifying each.
4. **Verify zero usage** before removing. Where a static check can't prove it, say which check you ran.
5. **Remove completely.** Delete the code with its tests, documentation and configuration.
