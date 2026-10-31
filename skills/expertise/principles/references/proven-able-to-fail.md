# Proven able to fail

Watch a check go red once before trusting it.

A check that cannot fail reports safety that does not exist, so the bug it should catch ships unseen.

- Prove a test as `test-writing` says.
- Show a gate or hook blocking the case it exists to block with a real attempt, alongside a case it admits.
- Make a helper that loops or retries fail at its limit with the last state it saw, rather than return quietly.
- Break code to prove a check only in a temporary worktree, so the working tree stays untouched.
- Prove a check again after rewriting it.
- Make a check able to fail before wiring it in.

Example: a hook that refuses a commit subject over 50 characters is run on a 51-character subject and a 50-character one. It refuses the first and admits the second.
