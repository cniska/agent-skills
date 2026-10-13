# Proven able to fail

A check that cannot fail is worse than none: it reports safety that does not exist. Before trusting a test, gate, hook, lint rule or health check, break what it guards once, watch it go red, and put it back.

- A test claiming an invariant fails when the invariant's code is removed.
- A gate or hook blocks the case it exists to block, shown with a real attempt, alongside a case it admits.
- A helper that loops or retries fails at its limit, with the last state it saw, rather than returning quietly.
- A check rewritten after it was proven is proven again.
- A check is made able to fail before it is wired in; scaffolding that cannot fail yet is not wired up.
