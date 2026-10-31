---
name: test-writing
description: Write tests that catch a named bug and are proven able to fail. Use when adding tests to existing code, pinning behavior before a refactor, or closing a gap a review or audit named.
---

# Test writing

Write each test against a bug it would catch, in the repo's own suite, and watch it fail before trusting it. Driving new behavior test-first is its own step; this skill is how any single test is written, and the whole job when the code already exists.

## Workflow

1. **Name the bug.** State the regression or wrong input the test would catch. Write a test only for a bug you can name.
2. **Read the existing suite.** Use its runner, layout, fixtures, helpers and naming. Add a new helper or fixture only when none fits.
3. **Pick the lowest level that observes the behavior** through the interface its caller uses. Go up a level only when the behavior lives in the wiring between parts.
4. **Write it.** One behavior per test, named for that behavior in plain terms.
5. **Prove it can fail**: watch it go red for the reason named in step 1, then pass on the change. Prove it in a temporary worktree, leaving the working tree as it was. A test that passes either way documents the behavior without holding it.
   - A test whose commit changes the behavior it covers runs against the parent commit there, and must fail.
   - A test of code its commit leaves unchanged, such as an invariant's, is proven by breaking that code there and watching the test fail.
6. **Run the repo's own check**: what CI runs, or its test, typecheck and lint scripts when there is no CI. Report any test that could not be run, and any failure unrelated to the tests as separate from them.

## Existing behavior

Before a refactor, pin what the code does now, including behavior that looks odd. When current behavior looks like a bug, ask before any test encodes it as expected. Any fix for it goes in a change of its own, apart from the tests. With no one to ask, leave it untested and report it with the input that shows it.

## What matters

- **Test the contract the caller depends on**: observable behavior through public interfaces, and error paths with meaningful recovery or a consequence the user sees. Leave what the type system already guarantees to the type system. A test that would survive a complete rewrite of the internals is testing the right thing.
- **Pin wire values as literals**: header names, record fields, status codes, error reasons and printed output. Importing the production constant makes a rename pass its own test.
- **Assert the outcome the caller sees**, not the call sequence that produced it or that a stub was called.
- **Keep unit tests offline.** Fake only at system boundaries, such as the network, third-party APIs, the database and the file system, and use the real implementation everywhere else. Even at a boundary, use the real implementation where practical, such as a scratch directory in place of a faked file system. A real end-to-end run against a live service is a separate step the developer opts into.
- **Let each test stand alone.** Prefer descriptive and meaningful phrases over DRY (DAMP), so each test says what it verifies without the reader chasing shared setup.
- **Fixtures copy a format, never real values.** Use synthetic data in place of production records, personal data, real credentials or live accounts. Make a fake secret obviously fake, such as `test-api-key`, since one shaped like a provider's real key looks like a leak to secret scanning.

## Isolation

- **Hermetic.** Each test builds its own scratch directory, data and environment, and neither reads nor writes anything the machine holds: not the network, the real home directory, a tool's own data, the user's keychain or other secret store (save in an opt-in integration run under a service name of its own, cleaned up after), their app defaults, or what another test left behind.
- **A tool's config emptied.** A tool the test runs reads the machine's user and system config and the variables it inherits, so point that config at an empty one and drop the tool's own inherited variables, as [tools](references/tools.md) shows for git.
- **Concurrent and parallel.** Give each test its own state, ports and paths, and assume no order between tests. Set the suite to run concurrently and across parallel workers wherever the runner allows, serially only where a shared resource forces it.
- **Controlled time.** Control time and randomness through the code's own seams or the runner's fakes, so no test sleeps or waits for a real timeout to elapse. Order steps across processes by handshake: the child prints a line and the test waits for that line. A wait the fakes cannot reach is passed in as [tools](references/tools.md) says.
