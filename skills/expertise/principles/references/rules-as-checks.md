# Rules as checks

A rule the code must keep is a check, not a sentence. A sentence is read differently by each agent and contributor, and only a reviewer catches a breach; a check fails the same way for everyone, on every commit.

- Take the strongest form that can hold the rule: a type that cannot represent the wrong state, then a rule the configured linter already has, then a test in the suite that scans the source, then a hook or CI step. A rule that covers only new and changed code scans the lines a diff adds, not the whole tree.
- When a review catches a breach of a mechanical rule, the fix adds the check that would have caught it.
- Prose in `AGENTS.md` or a skill keeps what needs judgment: naming, scope, design.
