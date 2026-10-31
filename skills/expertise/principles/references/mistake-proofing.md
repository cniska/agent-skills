# Mistake-proofing

Make a mistake impossible where you can, catch it with a check where you cannot, and ask anyone to remember it only when neither holds.

Each reader takes a sentence differently, and only a reviewer notices the slip; a guard holds the same way every time.

- Take the strongest form that can hold the rule, in this order:
  1. a type that cannot represent the wrong state, or a tool or default that does the step itself
  2. a rule the configured linter already has
  3. a test in the suite that scans the source
  4. a hook or CI step
  5. a sentence in a doc or skill
- Point a rule that covers only new and changed code at the lines a diff adds.
- Hold a step an agent must remember, such as when to stop, in a script, hook or tool default where one can hold it.
- When a review catches a mechanical slip, add the guard that would have stopped it.
- Keep in prose what needs judgment: naming, scope and design.

Example: reviewers keep finding a forbidden import. A lint rule that refuses it replaces the rules-file line that asked agents to avoid it.
