---
name: test-review
description: Review whether the tests of changed code would catch its likely bugs, finding coverage gaps, weak or unnecessary tests, and checks the diff weakened. Use when reviewing any diff, or when a suite went green after tests were skipped, deleted or stripped of assertions.
---

# Test Review

Review whether the tests of changed code would catch the bugs it can plausibly have, and whether each test is sound and earns its place.

## Scope

### 1. Coverage gaps

- new exported behavior with a plausible failure mode, named as the bug a missing test would catch
- new branches or error paths without coverage
- changed behavior the existing tests do not exercise
- renamed concepts or protocol terms without tests that cover the new form and, where needed, guard the old one

### 2. Edge cases

- boundary conditions: empty input, a missing file, null or undefined
- error recovery: command not found, parse failures
- configuration variants the code handles

### 3. Test quality

- tests asserting implementation details, such as call sequences that break on refactor, in place of behavior
- tests repeating what another test proves, with no failure mode unique to each layer
- tests that wait on the wall clock: a sleep, a real timeout left to elapse, a per-test timeout raised to fit one
- tests that are not hermetic: touching the network, the user's real home, a tool's own state, the real keychain or secret store outside an opt-in integration run, the real app defaults, or what another test left, or running a tool on the machine's user and system config and the variables the test inherited
- state shared between tests (a mutable global, fixed port, fixed path or assumed order) that breaks under concurrent or parallel runs, or a suite run serially, or a test marked serial, that shares no resource
- missing cleanup of temp files or cache state
- real data in tests: production records, personal data, real credentials, or live accounts and services, where fixtures should be synthetic
- a fake secret shaped like a real one (a provider's key prefix and length), which trips secret scanning and cannot be told apart from a leak, where an obviously fake value such as `test-api-key` belongs
- mocks that supply the asserted result, or that replace internals where the test should go through the real contract and mock only at boundaries
- tests that need exports, flags or wrappers with no production caller (`design-review`'s Code shaped for its tests)
- negative tests that pass because a different guard refuses the input first
- test names that do not read as specifications
- tests with more than one reason to fail, where each should assert one behavior

### 4. Unnecessary tests

- tests of trivial pass-through or type-only modules
- tests of what the type system guarantees
- tests of code that has since changed

### 5. Weakened checks

A change can make a check stop checking:

- a test skipped, deleted or narrowed so the suite no longer runs it
- assertions pulled out of a test that stayed, leaving it green either way
- an exclusion that drops code from coverage or mutation measurement in place of testing it
- a threshold edited down, or a suite moved out of the blocking stage

Label these `Restore` unless the diff or commit message says why. The weakening is the finding; the behavior left unguarded underneath is a second one.

## Evidence threshold

Flag a gap as `Must-add` or `Should-add` only when you can name the concrete bug or regression the test would catch. Coverage counts only as far as it catches such bugs.

For a new or changed test, identify the behavior, a regression it would catch, and why existing coverage misses it. Suggest removal only when stronger proof survives or no proof is needed. Keep source-reading tests that guard literal wire values or generated contracts.

- Low-value, no finding: `formatLabel()` has no test, but it is a trivial pass-through with no failure mode.
- High-value, a finding: `parseConfig()` on an empty file returns `undefined` but callers assume an object, so the untested path crashes startup.

## Workflow

1. Read the diff against the branch point, then the tests of each changed path.
2. For a diff across more packages or suites than one read can cover, gather gap candidates with one fast-tier reader per package or suite, if agents are available, and verify every candidate against the code.
3. Report each gap or test that meets the threshold.

## Output

Give each finding as the review report in `principles` lays out: **Where** names the source file and test file, **Rule** its label (`Restore`, `Must-add`, `Should-add` or `Remove`), **Why** what is untested and the concrete bug a test would catch, and **Instead** the fix direction. Severity follows the label: `Restore` is critical, `Must-add` major, `Should-add` and `Remove` minor. An optional test is not a finding. With nothing over the threshold, there is no finding.
