---
name: test-writing
description: Write tests that catch a named bug and are proven able to fail. Use when adding tests to existing code, pinning behavior before a refactor, or closing a gap a review or audit named.
---

# Test writing

Write each test against a bug it would catch, in the repo's own suite, and watch it fail before trusting it. `tdd` drives new behavior test-first; this skill is how any single test is written, and the whole job when the code already exists.

## Workflow

1. **Name the bug.** State the regression or wrong input the test would catch. If you can't name one, don't write the test.
2. **Read the existing suite.** Use its runner, layout, fixtures, helpers, and naming. Add a new helper or fixture only when none fits.
3. **Pick the lowest level that observes the behavior** through the interface its caller uses. Go up a level only when the behavior lives in the wiring between parts.
4. **Write it.** One behavior per test, named for that behavior in plain terms.
5. **Prove it can fail.** Break the code the test guards — delete the check, flip the condition — and watch it go red for the reason named in step 1. Restore and watch it pass. A test that passes either way documents the behavior without holding it.
6. **Run the repo's own check** — what CI runs, or its test, typecheck, and lint scripts when there is no CI. Report any test that could not be run, and any failure unrelated to the tests as separate from them.

## Existing behavior

Before a refactor, pin what the code does now, including behavior that looks odd.

When current behavior looks like a bug, ask before any test encodes it as expected, and never fix it inside a test change. With no one to ask, leave it untested and report it with the input that shows it.

## What to test

- Observable behavior through public interfaces.
- The contract the caller depends on, not the implementation behind it.
- Error paths that have meaningful recovery or user-facing consequences.
- Nothing the type system already guarantees.
- Prefer DAMP (descriptive and meaningful phrases) over DRY in tests — each test should independently communicate what it verifies.

## Assertions

- Pin wire values as literals: header names, record fields, status codes, error reasons. Importing the production constant makes a rename pass its own test.
- Assert the outcome the caller sees, not the call sequence that produced it.

## Mock at boundaries

Mock at system boundaries (database, network, file system, external APIs), not between internal functions. Prefer real implementations when practical. If a test would survive a complete rewrite of the internals, it is testing the right thing.

## Test data

Use synthetic data, never production records, personal data, real credentials, or live accounts. Make a fake secret obviously fake, such as `test-api-key`, never shaped like a provider's real key — secret scanning cannot tell it from a leak.

## Isolation

- **Hermetic.** Each test builds its own scratch directory, data and environment, and depends on nothing the machine holds: not the network, the real home directory, a tool's own data, or what another test left behind.
- **Safe to run at once.** No mutable global, fixed port, fixed path or assumed order shared between tests, so the suite passes under the runner's concurrent mode and across parallel workers.
- **No real time.** A test never waits on the wall clock: no sleep, and no real timeout left to elapse. Control time and randomness through the code's own seams or the runner's fakes. A wait the fakes cannot reach, such as a native library's lock timeout honored in another process, is passed in as a dependency the way the clock is: production passes the real value through the same parameter, and the test passes 0. Order steps across processes by handshake: the child prints a line and the test waits for that line.

## See also

- `tdd` for driving new behavior test-first
- `test-review` for judging whether tests are adequate
- `debug` for reproducing a defect before writing its regression test

## Red flags

- A test never seen failing, or rewritten since it was
- A test with no bug it would catch
- An assertion that imports the production constant it checks
- A sleep, a real clock, or unseeded randomness in a test
- A per-test timeout raised to fit a real wait
- A test that reads the real home directory, a tool's own data or the network, or relies on another test's leftovers
- A fixed port, fixed path or mutable global shared between tests
- Production records, personal data, or real credentials in a fixture
- A fake secret with a real provider's prefix or length
- Mocking internals instead of testing through public interfaces
- Pinning a suspected bug as expected behavior without asking
- A new helper or fixture where the suite already has one
