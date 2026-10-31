---
name: formal-verification-setup
description: Create or update a project-local formal verification skill whose check model-checks or proves the costliest promise the tests seldom exercise, run as one of the repo's checks. Use when concurrency, retry logic, a state machine, a parser or unsafe memory handling needs a guarantee a test suite cannot give, or when an existing formal verification skill may have drifted from the code.
---

# Formal verification setup

A test covers the cases someone wrote down. A formal check covers all of a stated scope, such as each interleaving a model allows, each input below a bound, or the whole input space. This skill finds where in the repo that reach pays off most, checks one property there, and hands the next agent, arriving cold mid-change, a project-local skill to recheck it. The owner has to be able to rely on its verdict and act on it without knowing the checker's syntax.

## What matters

- **One formal verification skill per project.** Any project-local skill counts, hand-written or not, whose check feeds named source to a model checker, a prover or a verifier that reads the code itself, or drives property-based inputs through named functions over a stated scope. A run realigns it under its own name and keeps it the only one.
- **The skill lives with the repo's own agent skills**, apart from any skills the repo ships to others. The check lives in the repo's own tool setup and task runner, beside its other checks.
- **Work on a topic branch in its own worktree and commit there**, leaving pushing and the PR to the user.

## Modes

- **Create** writes the project's formal verification skill when it has none, as [create](references/create.md) says.
- **Update** realigns an existing one and its check with today's code, as [update](references/update.md) says.

## Output

Name the mode, the skill, the check's command, and the files added or changed.

- **Create** states the property and its harm, the tool and why, the bounds, the wall-clock time, what the check found, and what it leaves out.
- **Update** gives each check one outcome: **in sync** (nothing since the sync commit changes what it describes, and it passes), **updated** (revised to match today's code, and green), **bug** (the model matches the code, which violates the property), or **blocked** (realigning or running it failed, with the cause). A check may be updated and bug at once. With the commits read, it lists each change to the model and its reason, the break used to prove a rerun pass, each bug in plain steps, and what is still uncovered. A pass that turned into a failure after the update is named as a stale pass.

Model updates land in their own commit, apart from any product fix.
