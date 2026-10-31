---
name: review
description: Review a whole change, always for correctness, tests and security and in each other area only when the diff touches it, and return the findings to whoever ran the review. Use when a feature branch is ready to land, on a change whose commits already landed, or on someone else's PR.
---

# Review

Review a whole change and return one report of its findings to whoever ran the review. `correctness-review`, `test-review` and `security-review` run on every change, and each other area runs only when the diff touches it. Leave the code and the history as you found them: whoever ran the review fixes its findings and queues its follow-ups.

The change is the current branch's diff against the branch it lands on, a given commit range, the diff and log files a brief names, or someone else's PR by URL or number. Code already on the default branch with no change to bound it is `audit`.

## Scope

Review the diff, reading enough surrounding code and docs to understand conventions and boundaries. Sort each problem you find, there or in the diff, by whether the change caused it, as the review report in `principles` says.

Report each issue under one area. A finding backed by the repo's own docs, contracts or nearby code belongs to Architecture or Maintainability. One that holds regardless of the repo belongs to Design. Where a Design rule and a documented repo convention conflict, the convention wins: Design raises nothing, and Maintainability reports only a departure from the convention.

## Change sizing

Before reviewing, check the diff size:

- About 100 lines: reviewable in one pass.
- About 300 lines: fine when it is one logical change.
- About 1000 lines or more: ask the author to split it before reviewing.

Refactoring mixed with feature work is two changes. Flag it.

## Areas

| Area | Skill | Runs when |
|------|-------|-----------|
| Correctness | `correctness-review` | always |
| Tests | `test-review` | always |
| Security | `security-review` | always |
| Documentation | `doc-review` | docs change, or behavior a doc describes changes |
| Performance | `performance-review` | the diff adds work on a hot path, a loop over unbounded data, a query or a network call |
| Maintainability | `maintainability-review` | the diff changes code |
| Design | `design-review` | the commits had no per-commit `design-review`, such as someone else's PR |
| Architecture | `architecture-review` | as Design |

## Workflow

1. Determine the scope: the commits and the files changed against the branch the change lands on, the same over a given range, the diff and log files the brief names, or a PR's description and diff. When the scope holds no commit, report that and stop.
2. Read the changed files in full, plus the project's convention docs, such as `AGENTS.md`, `CLAUDE.md` and `CONTRIBUTING.md`. On a complex or unfamiliar change, run `explain-diff` first for the understanding the review judges against. **Review the tests first**, since they reveal intent and coverage gaps.
3. Pick the areas from the table, reading each "Runs when" against the diff.
4. When the diff is wider than you can hold in one read and you can start agents, fan out **fast-tier** sub-agents, one per independent question rather than one per file, to surface candidate findings. Verify each one yourself before including it.
5. Load each picked area's skill and apply its criteria to the diff, one pass per area, attaching evidence to every finding. Run Design first when it runs, so Architecture and Maintainability report only what Design did not. When a skill fails to load, say so under that area.
6. When the change adds a dependency or a database migration, check it as [dependencies and migrations](references/dependencies-and-migrations.md) says.
7. Merge the findings: deduplicate, and keep the strongest framing of each root issue.
8. Return the report to whoever ran the review. Post a PR's report to the PR only when asked.

## Review checks

Look for these patterns in every review:

- term drift across code, schemas, tests and docs after a rename or protocol change
- shared contracts that blur distinct intent where separate variants or schemas would be clearer
- escape hatches, bypass flags and special-case options that are broader than the behavior they enable
- an updated implementation that leaves stale references behind in tests or docs
- a small diff with effects beyond the changed files: name the fact its safety depends on, trace the relevant callers or contracts, and run a focused check when practical, reporting it as unproven when the check cannot run

## Report

One report, in the review report shape from `principles`, so the area skills' findings merge without translation. Each area skill hands its findings back to this review, and only this review makes a report tool's call, once, after merging. Each finding's **Rule** names its area and the rule or check it breaks, and keeps the severity its area skill gave it. Clean names every area that ran and what it checked. Name each area the table skipped, with the "Runs when" it failed: under `not_run` in a report tool's call that has the field, or else in a closing line after the four sections, `Not run: <area> (<reason>), ...` or `Not run: none`, above any closing lines the caller asks for.
