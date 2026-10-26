---
name: review
description: Review a whole change, always for correctness and tests and in each other area only when the diff touches it, and return the findings to whoever ran the review. Use when a feature branch is ready to land, on a change whose commits already landed, or on someone else's PR.
argument-hint: "[pr-url-or-number | commit-range]"
---

# Review

Review a whole change and return one report of its findings to whoever ran the review. `correctness-review` and `test-review` run on every change; each other area runs only when the diff touches it. Change nothing and commit nothing, in any mode: whoever ran the review fixes its findings and queues its follow-ups.

Two modes: **Self** (no argument, or a commit range) — the current branch's diff against the branch it lands on, or the given range, or the diff and log files the brief names; **PR** (URL or number) — someone else's PR. Code already on the default branch with no change to bound it is `audit`.

## Scope

Review the diff, reading enough surrounding code and docs to understand conventions and boundaries. A defect in that surrounding code is placed as the review report in `principles` says: a finding when it blocks the change, a follow-up when it is a real defect that does not, and dropped when it is a style point.

Do not duplicate the same issue across areas. A finding backed by the repo's own docs, contracts or nearby code belongs to Architecture or Maintainability; one that holds regardless of the repo belongs to Design. Where a Design rule and a documented repo convention conflict, the convention wins: Design raises nothing, and Maintainability reports only a departure from the convention.

## Change sizing

Before reviewing, check the diff size:

- ~100 lines: good, reviewable in one pass.
- ~300 lines: fine when it is one logical change.
- ~1000 lines: too large — ask the author to split before reviewing.

Refactoring mixed with feature work is two changes. Flag it.

## Areas

| Area | Skill | Runs when |
|------|-------|-----------|
| Correctness | `correctness-review` | always |
| Tests | `test-review` | always |
| Security | `security-review` | the diff touches hooks, gates, auth, permissions, secrets or input from outside the process |
| Documentation | `doc-review` | docs change, or behavior a doc describes changes |
| Performance | `performance-review` | the diff adds work on a hot path, a loop over unbounded data, a query or a network call |
| Maintainability | `maintainability-review` | the diff changes code |
| Design | `design-review` | the commits had no per-commit `design-review`, such as someone else's PR |
| Architecture | `architecture-review` | as Design |

## Workflow

### Self

1. Determine the scope: `git log <base>..HEAD --oneline` and `git diff <base>...HEAD --stat` against the branch it lands on, the same over a given range, or the diff and log files the brief names. If the scope holds no commit, report and stop.
2. Read changed files in full, plus any project-level convention docs. **Review tests first** — they reveal intent and coverage gaps.
3. Pick the areas from the table, reading each "Runs when" against the diff.
4. When the diff is wider than you can hold in one read and you can start agents, fan out **fast-tier** sub-agents — one per independent question, not one per file — to surface candidate findings. Verify each before including it.
5. Load each picked area's skill and apply its criteria to the diff, one pass per area. Run Design first when it runs; Architecture and Maintainability then report only what Design did not. If a skill fails to load, say so under that area rather than improvising.
6. Merge findings: deduplicate, keep the strongest framing per root issue.
7. Return the report to whoever ran the review.

### PR (URL or number)

1. `gh pr view <N>` for metadata; `gh pr diff <N>` for the diff. Read repo conventions — `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`.
2. Fan out as in Self step 4. Verify findings yourself.
3. Pick and run the areas as in Self steps 3 and 5. Attach evidence to every finding.
4. Return the report; post it with `gh pr review` only when asked.

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

If the change includes database migrations, load `database-design` and check the migration against its rules, filing findings under the areas above — a schema defect is a correctness or security finding, not an area of its own. Trace every view and function that joins a changed table.

## Report

One report, in the review report shape from `principles`, so the area skills' findings merge without translation. Each finding's **Rule** names its area and the rule or check it breaks, and keeps the severity its area skill gave it. `## Clean` names every area that ran and what it checked; an area the table skipped is not listed.

## See also

- the area skills step 5 loads, for each area's depth
- `audit` for a read-only sweep of code already on the default branch
- `database-design` for the schema rules a migration is checked against
- `principles` for the review report this skill returns
- `explain-diff` for building the understanding this skill judges against, on a complex or unfamiliar change

## Red flags

- Reviewing only the diff without reading touched files in context
- Skipping correctness or tests, or running an area the diff does not touch
- Duplicating the same root issue across areas
- Editing or committing during a review, in any mode
- Generic cleanup wishlists
- Speculative issues without evidence
- Broad rewrite suggestions out of scope
- An accept while a finding stands under Findings, or "LGTM" without evidence of review
- A defect in code the change does not touch returning the change without blocking it, or a nit there reported at all
- Softening real issues — if it's a bug, say so directly
