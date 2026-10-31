---
name: principles
description: Apply a named engineering principle that more than one skill relies on, by reading only that principle's file. Use when a skill or route names a principle, or to cite the rule behind a review finding.
---

# Principles

A principle that more than one skill needs lives here once, so every skill that names it applies the same rule. Read the file for each principle the current step names, not the whole set.

| Principle | The rule in one line | File |
|---|---|---|
| No comments | The why lives in names, tests, tool config or the owning doc, never in a comment | [no-comments.md](references/no-comments.md) |
| Chesterton's Fence | Find out why something exists before removing or changing it | [chestertons-fence.md](references/chestertons-fence.md) |
| Proven able to fail | Watch a check go red once before trusting it; prove a test in a temporary worktree, never the working tree | [proven-able-to-fail.md](references/proven-able-to-fail.md) |
| Fix the cause | Remove the state that causes a failure, never guard in front of it | [fix-the-cause.md](references/fix-the-cause.md) |
| No transitional architecture | Replace, migrate and remove; never keep the old path alive beside the new | [no-transitional-architecture.md](references/no-transitional-architecture.md) |
| Mistake-proofing | Make a mistake impossible; else catch it with a lint, test or hook; ask anyone to remember only as a last resort | [mistake-proofing.md](references/mistake-proofing.md) |
| No text heuristics | A step reads structured data or an explicit command, never the phrasing a writer happened to choose | [no-text-heuristics.md](references/no-text-heuristics.md) |
| No drift | A change updates what describes, repeats, names or depends on it | [no-drift.md](references/no-drift.md) |
| Review report | Every review reports in one shape, fixes what the change causes and what blocks it, queues other real defects, and accepts only when there is no finding | [review-report.md](references/review-report.md) |
| Verify at the source | Settle each factual claim where it is defined, and cite that place; restate the owner in clear English, never quoting the owner's wording | [verify-at-source.md](references/verify-at-source.md) |

A principle only one skill uses stays in that skill. It moves here when a second skill needs it.

## See also

- `design-review`, which cites these principles behind its findings
- the other review skills and `audit`, which report in the review report shape
- `code-writing`, `simplify`, `debug`, `test-writing`, `deprecation`, `docs-writing`, `agents-md`, `writing`, `skill-writing`, which each name the principles their steps apply
