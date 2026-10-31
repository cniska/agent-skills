---
name: tdd
description: Drive a behavior test-first in red-green-refactor cycles of one failing test, the least code that passes it and a cleanup. Use when building a feature's crucial logic or fixing a bug test-first.
---

# TDD

Build the change one behavior at a time, each driven by a test that failed first. A test written before its code proves it can fail, and the smallest passing step keeps every line tied to a test.

## Workflow

1. **Understand the behavior.** Read enough code to know what the change should do and where it belongs.
2. **Write one failing test** for the next behavior, as `test-writing` says. Run it and see it fail because the behavior is missing.
3. **Make it pass** with the least code that does.
4. **Refactor while green.** Improve names, remove duplication and simplify structure, running the tests after each change. Put any why into a name, type or test, as no comments in `principles` says.
5. **Repeat** from step 2 with the next behavior.

Write the next test only once the current one passes.
