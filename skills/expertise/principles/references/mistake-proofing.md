# Mistake-proofing

Prefer making a mistake impossible over catching it, and catching it over asking anyone to remember. A sentence is read differently by each agent and contributor, and only a reviewer notices the slip; a guard holds the same way for everyone, every time. This holds for code, configuration and the agent workflow alike.

- Take the strongest form that can hold the rule: a type that cannot represent the wrong state, or a tool or default that does the step itself; then a rule the configured linter already has, such as one refusing a forbidden import; then a test in the suite that scans the source; then a hook or CI step. A sentence in a doc or skill comes last. A rule that covers only new and changed code scans the lines a diff adds, not the whole tree.
- In the agent workflow, a step a skill asks an agent to remember, such as when to stop, is a script, hook or tool default where one can hold it.
- When a review catches a mechanical slip, the fix adds the guard that would have stopped it.
- Prose in `AGENTS.md` or a skill keeps what needs judgment: naming, scope, design.
