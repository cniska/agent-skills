---
name: simplify
description: Simplify code by reducing complexity while preserving exact behavior. Use when a review finding names a move, or in the refactor step of tdd.
---

# Simplify

Make code easier to read, understand and change while it keeps exactly the behavior it has. Fewer lines are not the goal. Judge each change by whether a new contributor would understand the result faster than the original.

## Steps

1. **Learn why the code is there before changing it**, as Chesterton's Fence in `principles` says.
2. **Match each smell to one named move**, and name the move in the commit subject so each commit holds one transformation. When two moves fit equally or none fits cleanly, extract a function. A move applied only because the code looks like its smell makes a worse diff than no move.
   - **Nesting three or more levels deep**: replace nested conditionals with guard clauses.
   - **A function of 50 or more lines**: extract functions, split by responsibility.
   - **Computing and formatting in one function**: split phase.
   - **Repeated branching on the same value**: replace the conditional with polymorphism or a lookup table.
   - **A complex expression stored in a temp**: replace the temp with a query.
   - **A function that reads another module's data more than its own**: move the function to the data.
   - **Repeated groups of arguments**: introduce a parameter object.
   - **Nested ternaries**: replace them with if/else or a lookup.
   - **Generic names** such as `data`, `result` or `temp`: rename to describe the content.
   - **Duplicated logic**: extract a shared function once there are three small copies or two substantial ones.
   - **Dead code**: remove it once it is confirmed unreachable.
   - **Comments**: remove them, as no comments in `principles` says.
   - **A wrapper that adds no policy**: inline it, judged against the language's own idiom. A newtype, a constructor that delegates to a default, and accessors over private fields are conventional, so they stay.
3. **Apply one move at a time, and run the tests after each.** When the tests fail, revert the move and reconsider. Keep refactoring in commits of its own, apart from feature work.
4. **Verify.** Every existing test passes unchanged, since a test that needed changing means the behavior changed. The diff holds the moves and nothing else.
