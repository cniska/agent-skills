---
name: simplify
description: Simplify code by reducing complexity while preserving exact behavior. Use when a review finding names a move, or in the refactor step of tdd.
---

# Simplify

Reduce complexity while preserving exact behavior. The goal is not fewer lines — it's code that is easier to read, understand, and modify. Every simplification must pass: "Would a new contributor understand this faster than the original?"

Do not simplify code you don't understand yet, code that is already clean, or code you're about to rewrite entirely.

## Workflow

### 1. Understand before touching (Chesterton's Fence)

Before changing or removing anything, apply Chesterton's Fence from `principles`.

### 2. Identify opportunities

Each smell maps to one named move — name it in the commit subject to keep one transformation per commit. When two moves fit equally or none fits cleanly, extract function is the honest fallback; a move applied because it pattern-matches produces a worse diff than no move at all.

- **Deep nesting (3+ levels)** — replace nested conditionals with guard clauses
- **Long functions (50+ lines)** — extract function, split by responsibility
- **Compute and format in the same function** — split phase
- **Repeated branching on the same value** — replace conditional with polymorphism, or a lookup table
- **Complex expression stored in a temp** — replace temp with query
- **A function that reads another module's data more than its own** — move function to the data
- **Repeated argument groups** — introduce parameter object
- **Nested ternaries** — replace with if/else or lookups
- **Generic names** (`data`, `result`, `temp`) — rename to describe content
- **Duplicated logic** — extract to shared function; three small copies or two substantial ones, and don't touch copies kept deliberately apart (boundary-local, conditionally compiled)
- **Dead code** — remove after confirming truly unreachable
- **Comments** — remove them, as no comments in `principles` says
- **Wrappers that add no policy** — inline function, judged against the language's own idiom: a newtype, a constructor delegating to a default, or accessors over private fields are conventional, not empty wrappers

### 3. Apply incrementally

One move at a time. Run tests after each change. If tests fail, revert and reconsider. Separate refactoring from feature work.

### 4. Verify

All existing tests must pass without modification — if tests needed updating, you likely changed behavior. The diff should be clean with no unrelated changes mixed in.
