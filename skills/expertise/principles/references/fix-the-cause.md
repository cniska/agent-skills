# Fix the cause

A fix removes the state that causes the failure. A change that adds a condition in front of state it leaves in place is a symptom fix.

- A second fix resting on the same assumption as one that already failed the same check is the signal to question the assumption before writing a third.
- A constant no test can prove correct, such as a hardcoded offset or a nudge, is the tell that the cause is untouched.
- No fallback, default or catch-and-continue written because the correct behavior was unclear. Ask, or fail where the caller can see it. Degradation chosen on purpose names itself and records what it drops.
- Where the cause is out of reach, stop and state the real options rather than patching around it.
