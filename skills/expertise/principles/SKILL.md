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
| Rules as checks | A mechanical rule is a type, lint, test or hook, not a sentence | [rules-as-checks.md](references/rules-as-checks.md) |
| No drift | A change updates what describes, repeats, names or depends on it | [no-drift.md](references/no-drift.md) |
| Review report | Every review reports findings in one shape, each fixed, and accepts only when none stands | [review-report.md](references/review-report.md) |
| Verify at the source | Settle each factual claim where it is defined, and cite that place | [verify-at-source.md](references/verify-at-source.md) |

A principle only one skill uses stays in that skill. It moves here when a second skill needs it.

## See also

- `design-review`, which cites these principles behind its findings
- the other review skills and `audit`, which report in the review report shape
- `code-writing`, `simplify`, `debug`, `test-writing`, `deprecation`, `docs`, `agents-md`, `writing`, `skill-writing`, which each name the principles their steps apply

## Red flags

- A skill restating a principle from this set instead of naming it
- Reading every principle file when the step names one
- A principle here that only one skill uses
- A finding that cites a principle without applying its file's rule
