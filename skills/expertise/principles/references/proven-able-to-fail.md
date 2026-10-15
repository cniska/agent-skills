# Proven able to fail

A check that cannot fail is worse than none: it reports safety that does not exist. Before trusting a test, gate, hook, lint rule or health check, watch it go red once, never by breaking code or a test in the working tree.

- A test whose commit changes the behavior it covers runs against the parent commit in a temporary worktree, and must fail there.
- A test of code its commit leaves unchanged, such as an invariant's, is proven by breaking that code inside a temporary worktree and watching the test fail.
- A gate or hook blocks the case it exists to block, shown with a real attempt, alongside a case it admits.
- A helper that loops or retries fails at its limit, with the last state it saw, rather than returning quietly.
- A check rewritten after it was proven is proven again.
- A check is made able to fail before it is wired in; scaffolding that cannot fail yet is not wired up.
