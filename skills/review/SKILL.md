---
name: review
description: Run all review dimensions against a diff. Use when reviewing a feature branch before merge or reviewing someone else's PR.
argument-hint: "[pr-url-or-number]"
---

# Review

Run all review dimensions against the current branch and produce one unified review. Approve when a change improves overall code health, even if it isn't perfect.

Two modes: **Self** (no argument) — current branch diff against `main`; **PR** (URL or number) — someone else's PR. Code already on `main` with no diff is `audit`.

## Scope

Review only the diff, but read enough surrounding code and docs to understand conventions and boundaries.

Do not duplicate the same issue across categories. A finding backed by the repo's own docs, contracts or nearby code belongs to Architecture or Maintainability; one that holds regardless of the repo belongs to Design. Where a Design rule and a documented repo convention conflict, the convention wins: Design raises nothing, and Maintainability reports only a departure from the convention.

## Change sizing

Before reviewing, check the diff size:

- ~100 lines: good, reviewable in one pass.
- ~300 lines: acceptable if one logical change.
- ~1000 lines: too large — ask the author to split before reviewing.

Refactoring mixed with feature work is two changes. Flag it.

## Workflow

### Self (no argument)

1. If the branch was built in a long session, suggest the user run `handoff` and re-run `/review` in a fresh session for a cleaner read. Otherwise proceed here.
2. Determine diff scope: `git log main..HEAD --oneline` and `git diff main...HEAD --stat`. If no commits ahead of `main`, report and stop.
3. **Get an independent second opinion first.** Spawn a fresh subagent to review the diff independently — it isn't anchored to the author's mental model. Give it the diff, intent, and specific failure modes to probe. Ask for concrete findings with evidence only. Withhold your own read of the diff — hand over conclusions and what comes back is agreement with them. Run it on a **balanced-tier** model.
4. Read changed files in full, plus any project-level convention docs. **Review tests first** — they reveal intent and coverage gaps.
5. When the diff is wider than you can hold in one read, fan out **fast-tier** sub-agents — one per independent question, not one per file — to surface candidate findings. Verify each before including it.
6. Run every dimension pass in this session — load each skill (`design-review`, `correctness-review`, `maintainability-review`, `architecture-review`, `doc-review`, `security-review`, `performance-review`, `test-review`) and apply its criteria to the diff, one pass per dimension. Run Design first; Architecture and Maintainability then report only what Design did not. If a skill fails to load, say so in that category's output rather than improvising.
7. Fold in the second opinion's findings. Verify each; discard false positives.
8. Merge findings: deduplicate, keep strongest framing per root issue.
9. Label every finding by severity (see below). Fix all findings by default — commit each fix as its own subject-scoped commit.

### PR (URL or number)

1. `gh pr view <N>` for metadata; `gh pr diff <N>` for the diff. Read repo conventions — `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`.
2. When the PR is wider than you can hold in one read, fan out **fast-tier** sub-agents — one per independent question. Verify findings yourself.
3. Run every dimension pass (as in Self step 6). Attach evidence to every finding.

## Severity

Label every finding explicitly — an unlabeled finding is ambiguous. This scale is canonical; dimension skills map their labels onto it.

| Label | Meaning |
|-------|---------|
| **Critical:** | Blocks merge — security, data loss, broken functionality |
| **Fix:** | A real defect or convention violation; address before merge |
| **Consider:** | Worth thinking about, not required |
| **Nit:** | Style preference, minor improvement |

Order output Critical → Fix → Consider → Nit. In the summary table, Consider and Nit both count as optional.

## Review checks

Look for these patterns in every review:

- term drift across code, schemas, tests, and docs after a rename or protocol change
- shared contracts that blur distinct intent where separate variants or schemas would be clearer
- escape hatches, bypass flags, and special-case options that are broader than the behavior they enable
- updated implementation that leaves stale references behind in tests or docs
- for a small diff with effects beyond the changed files, name the fact its safety depends on, trace the relevant callers or contracts, and run a focused check when practical; report it as unproven if the check cannot run

## Dependency review

If the change adds a dependency, check:
- Does the existing stack already solve this?
- Is it actively maintained?
- What's the size impact?
- Any known vulnerabilities?

## Migration review

If the change includes database migrations, load `database-design` and check the migration against its rules, filing findings under the dimensions above — a schema defect is a correctness or security finding, not a category of its own. Trace every view and function that joins a changed table.

## Fix policy

- **Self:** fix all findings by default — including trivial ones — each as its own subject-scoped commit. Small issues left unfixed accumulate into tech debt. Where a finding is structural rather than a defect — complexity, misplaced logic, indirection — load `simplify` and apply its named moves, one per commit.
- **PR:** never commit to someone else's branch. Deliver findings as a review (`gh pr review`), or a comment block if asked.

## Output

One section per review dimension (Design, Correctness, Maintainability, Architecture, Documentation, Security, Performance, Tests), noting dimensions with no findings. Always end with this summary table — one row per dimension, counts of findings per severity (Consider and Nit both count as Optional):

| Category | Critical | Fix | Optional |
|----------|----------|-----|----------|
| Design | 0 | 0 | 0 |
| Correctness | 0 | 0 | 0 |
| Maintainability | 0 | 0 | 0 |
| Architecture | 0 | 0 | 0 |
| Documentation | 0 | 0 | 0 |
| Security | 0 | 0 | 0 |
| Performance | 0 | 0 | 0 |
| Tests | 0 | 0 | 0 |

## See also

- `design-review`, `correctness-review`, `maintainability-review`, `architecture-review`, `doc-review`, `security-review`, `performance-review`, `test-review` for dimension-specific depth
- `audit` for a read-only sweep of code already on `main`
- `database-design` for the schema rules a migration is checked against
- `simplify` for acting on structural findings
- `explain-diff` for building the understanding this skill judges against, on a complex or unfamiliar change

## Red flags

- Reviewing only the diff without reading touched files in context
- Duplicating the same root issue across categories
- Generic cleanup wishlists
- Speculative issues without evidence
- Broad rewrite suggestions out of scope
- "LGTM" without evidence of review
- Softening real issues — if it's a bug, say so directly
- Accepting "I'll fix it later" — require cleanup before merge
