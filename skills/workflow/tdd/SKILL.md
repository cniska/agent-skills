---
name: tdd
description: Drive implementation with red-green-refactor. Use when building features or fixing bugs test-first.
---

# TDD

Drive implementation through the red-green-refactor cycle.

## Workflow

1. **Understand the behavior**: read enough code to know what the change should do and where it belongs.
2. **Write one failing test**: the test describes the next behavior to add, written as `test-writing` says. It must fail for the right reason.
3. **Make it pass**: write the minimum code to pass the test. Nothing more.
4. **Refactor**: clean up while green. Improve naming, remove duplication, simplify structure. Run tests after each change. No comments: a *why* goes into a name, type or test.
5. **Repeat**: pick the next behavior and go back to step 2.

One test at a time. Each cycle is vertical — one test, one implementation, one refactor pass. Do not write multiple tests before implementing.
