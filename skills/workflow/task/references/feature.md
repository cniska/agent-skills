# Feature

When: new or changed behavior.

1. The branch or worktree the repo prescribes.
2. `plan` when the shape is unclear or spans more than one slice; `second-opinion` on the agreed shape, by a `researcher` agent where the host can start one, then `design-review` of the result by a fresh agent.
3. `code-writing` before the first edit, with `database-design` or `ui-design` when the change touches a schema or an interface.
4. `build`, slice by slice; `tdd` for crucial logic.
5. Each commit: `design-review` by a fresh agent.
6. The repo's checks, and its running-app proof where it has one.
7. `review` on the whole change, then land as the repo's rule says.

Report: what landed and how it was proven.
