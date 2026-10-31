# Fix the cause

Remove the state that causes a failure, rather than adding a condition in front of it.

A condition in front of the cause is a symptom fix: it leaves the state in place, so the failure returns by another path.

- When a second fix rests on the same assumption as one that already failed the same check, question the assumption before writing a third.
- Read a constant no test can prove correct, such as a hardcoded offset or a nudge, as the sign that the cause is untouched.
- When the correct behavior is unclear, ask, or fail where the caller can see it. Degradation chosen on purpose names itself and records what it drops.
- When the cause is out of reach, stop and state the real options.

Example: a list shows a deleted item until refresh. Filtering it out in the view hides it; dropping it from the cache on delete fixes it.
