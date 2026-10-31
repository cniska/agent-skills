---
name: debug
description: Debug a failure to its root cause by reproducing it, localizing it, fixing the cause and guarding against its return. Use when a test fails, a build breaks, or runtime behavior differs from what the code promises.
---

# Debug

When something breaks, find out why before changing anything else. Keep the evidence, fix the root cause and leave a guard that fails if the bug comes back.

## Workflow

1. **Stop the line.** Hold new features and unrelated changes until the failure is understood, since each change made on top of it moves the evidence.
2. **Reproduce.** Make the failure happen reliably with the specific failing test, run alone. A defect found by reading has no failure yet, so first build the smallest command or test that shows it. When several failures surface at once, work the one that gives wrong results silently before the one that announces itself.
3. **Localize.** Run `search-sessions` for whether this failure came up before and what was tried. Find the layer and the change, bisecting the history where a command tells a good commit from a bad one. Decide whether the test, the code or the environment is wrong:
   - When behavior and a test diverge, fix the implementation unless the owner says the test is wrong.
   - Check the runtime and toolchain against what the project declares before blaming the code.
   - Check what each tool you call actually promises.

   When the bug spans several files and you can start agents, give a **fast-tier** reader the gathering: the failing test, the code paths involved and the recent history of the affected files. Analyze what it returns in this session. When the root cause is not obvious, switch to a **powerful-tier** model for the analysis.
4. **Reduce.** Strip the failure to the smallest case that still fails.
5. **Fix the root cause**, as fix the cause in `principles` says.
6. **Guard against recurrence.** Write a test that passes with the fix and is proven able to fail without it, as `test-writing` says. When the right guard is a lint rule, a CI step or a config check, add that instead and say so.
7. **Verify end to end.** Run the project's own commands, the ones its CI runs: the failing test, then the full suite. When there is no suite, or running it needs money, network or hardware you lack, run the cheapest check that still exercises the fix and name it.

## When the design is the cause

When the root cause turns out to be the approach itself, stop debugging and load `plan`. Fix the cause in `principles` names the signal. A patch on a wrong design returns as more bugs in other shapes.
