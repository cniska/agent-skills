# Bug fix

When: behavior that differs from what it should be.

1. The branch or worktree the repo prescribes.
2. `debug` to reproduce the failure and find its root cause. A design-level cause re-routes to Refactor.
3. `code-writing` before the first edit, with `database-design` or `ui-design` when the fix touches a schema or an interface.
4. `test-writing` for a guard test that fails without the fix.
5. Each commit: `simplify`, then `design-review` by a fresh agent.
6. The repo's checks, and its running-app proof where it has one.
7. `review` on the whole change, then land as the repo's rule says.

Report: the cause, the fix, and the proof.
