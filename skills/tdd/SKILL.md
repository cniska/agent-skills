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
4. **Refactor**: clean up while green. Improve naming, remove duplication, simplify structure. Run tests after each change. Comments must earn their keep — a *why* a name, type, or test can't carry, never *what* the code does.
5. **Repeat**: pick the next behavior and go back to step 2.

One test at a time. Each cycle is vertical — one test, one implementation, one refactor pass. Do not write multiple tests before implementing.

## See also

- `build` for slice-by-slice execution
- `test-writing` for what to test, assertions, and mocking
- `test-review` for review-time test adequacy checks

## Red flags

- Writing all tests first, then all implementation (horizontal slicing)
- Testing the shape of data instead of behavior
- Refactoring while red
- Skipping the refactor step because tests pass
- Comments that restate the code instead of carrying a why
