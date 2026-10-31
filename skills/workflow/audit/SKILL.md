---
name: audit
description: Audit code already on the default branch in every review area, one reader per area, and report what holds and what does not while leaving the code as it is. Use for a read-only sweep of a project or path that no diff bounds.
---

# Audit

Examine code as it stands, one reader per review area, and report what holds and what does not. `review` judges a change; an audit judges code with no diff to bound it. The report goes to the user, who decides what work to request from it, so the code stays as found.

## Scope

Audit the whole project unless a narrower path is given. Name the revision and the scope. Read the project rules and the docs that state the scope's behavior and boundaries, and name any missing authority instead of assuming one. Enumerate the owned source and tests, leave out generated content, lockfiles and dependencies, and name any path that cannot be inspected.

Size the scope so each reader can read its relevant paths in full. Divide a larger audit by coherent module or boundary and report each part separately.

## Workflow

1. **Scope** the audit as above and record the revision.
2. **Start one read-only agent per area** on a **balanced-tier** model: `design-review`, `correctness-review`, `security-review`, `test-review`, `architecture-review`, `maintainability-review`, `doc-review`, and `performance-review` only where stated behavior or observed use names a sensitive path. Give each the scope, not your own read of it, with the revision, the project rules and its skill to load, since a reader handed a conclusion returns agreement with it. Tell each to read "the diff" as the full files in scope and to lift each diff-only limit: doc drift and structure as they stand, every reachable entry point, weakened checks traced through history instead of from a branch point, and coupling as it stands instead of what a change added.

   When the scope fits in one read, or agents are unavailable, run the passes in this session instead and keep their findings apart until the merge. On a small scope, an agent per area repeats the same full read for each pass.
3. **Search to locate, read to judge.** A reader may search for candidates, and reads the implementation, callers, tests and contracts before calling one a finding.
4. **Hold proposed test deletions to a higher bar.** Name the failure the test detects, the code it guards, the tests that overlap it and the stronger proof that remains. Treat a test that must change for a behavior-preserving refactor as suspect, and keep independent guards for wire values, security, storage and other contracts.
5. **Verify and merge.** Recheck every candidate at its source, resolve duplicates and contradictions, and keep the strongest framing of each root issue.

## Output

State the revision and the inspected scope, and each area that is `not_applicable` or `incomplete` with its reason. Then report in the review report shape from `principles`. Each finding's **Rule** names its area and the rule it breaks, and its **Why** gives the concrete consequence and the source evidence. For each unresolved case, say what would settle it.

`## Clean` lists only the areas that are clear, and an area is clear only once its relevant paths were read in full. A clean audit means every applicable area was checked in the stated scope and no finding survived verification.
