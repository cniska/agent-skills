---
name: audit
description: Audit existing code across every review dimension. Use for a read-only sweep of a project or path already on the default branch.
argument-hint: "[project-or-path]"
---

# Audit

Examine code as it stands, one reader per dimension, and report what holds and what does not. `review` judges a change; this skill judges an area with no diff to bound it. Leave the code unchanged — the report is for the user to decide what work to request.

## Scope

Audit the whole project when no narrower path is given. Name the revision and the area. Read the project rules and the docs that state the area's behavior and boundaries; name a missing authority instead of assuming one. Enumerate owned source and tests; skip generated content, lockfiles, and dependencies, and name any area that cannot be inspected.

Size the area so each reader can read its relevant paths in full. Divide a larger audit by coherent module or boundary and report each part separately.

## Workflow

1. **Scope** the area as above and record the revision.
2. **Spawn one read-only agent per dimension** — `design-review`, `correctness-review`, `maintainability-review`, `architecture-review`, `doc-review`, `security-review`, `performance-review`, `test-review` — on a **balanced-tier** model. Give each the same area and revision, the project rules, and its skill to load, with "the diff" read as the full files in scope and each diff-only limit lifted: pre-existing doc drift, every reachable entry point, weakened checks traced through history rather than a branch point, and coupling as it stands rather than what a change added. Withhold your own read — hand over a conclusion and what comes back is agreement with it. Run performance only where stated behavior or observed use names a sensitive path. When subagents are unavailable, or the area is small enough to hold in one read, run the passes separately in this session and keep their findings distinct until merging — on a small area, one agent per dimension repeats the same full read for each pass.
3. **Search to locate, read to judge.** A reader may grep for candidates but inspects the implementation, callers, tests, and contracts before calling one a finding.
4. **Hold proposed test deletions to a higher bar.** Name the failure the test detects, the code it guards, overlapping tests, and the stronger proof that remains. A test that must change for a behavior-preserving refactor is suspect; keep independent guards for wire values, security, storage, and other contracts.
5. **Verify and merge.** Recheck every candidate at its source, resolve duplicates and contradictions, and keep the strongest framing per root issue.

## Output

State the revision and inspected scope. Per finding: dimension, `file:line`, the concrete consequence, source evidence, and fix direction, labeled with `review`'s severity scale read without merge: **Critical** is a security hole, data loss, or broken behavior now; **Fix** is a real defect or convention violation. For each unresolved case, say what would settle it.

End with one row per dimension:

| Dimension | Status | Findings | Reason |
|-----------|--------|----------|--------|
| Design | findings / clear / not_applicable / incomplete | 0 | |
| Correctness | findings / clear / not_applicable / incomplete | 0 | |

`clear` requires reading the relevant paths in full, not a search. `not_applicable` and `incomplete` each need a reason. A clean audit means every applicable dimension was checked in the stated scope and no finding survived verification.

## See also

- `review` for judging a diff or PR
- `design-review`, `correctness-review`, `maintainability-review`, `architecture-review`, `doc-review`, `security-review`, `performance-review`, `test-review` for dimension-specific depth
- `simplify` for acting on structural findings once the user requests the work

## Red flags

- Treating a regex match or a style preference as a confirmed finding
- Marking a dimension clear after inspecting a sample
- A finding without its consequence and source evidence
- Editing code or committing during an audit
- Hiding an uninspected area behind a clean verdict
