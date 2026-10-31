---
name: verification-setup
description: Create or update the project-local skill that launches a changed build, drives it the way a user does and captures what the user sees, proven by a run before it is committed. Use when an agent cannot verify changed app behavior by running it, or when the project's verify skill may have drifted from the app.
---

# Verification setup

Give the next agent an executable path to launch a changed build, drive a feature the way a user does, and inspect what a user sees. That agent opens the skill cold, mid-task. Automated tests support its judgment, and its own run of the app is what settles it.

## What matters

- **One verification skill per project**, or in a monorepo one per area with a user surface, each area its own run. Its surfaces share it, with a recipe of their own where their launch or controls differ. Any project-local skill that launches, drives and observes the app counts, hand-written ones included, so update the one that exists. An existing skill that covers one narrow path becomes one feature file, and the skill grows around it the other sections [create](references/create.md)'s step 2 lists.
- **A shared skill installed from elsewhere is a harness** the project skill calls, used as it is.
- **The skill lives with the skills the repo's agents load**, apart from any skills the repo ships to others. With none, infer the team's tools from the agent config the repo carries, and ask only when that leaves it open.
- **Work on a topic branch in a worktree and commit locally**, leaving pushing and the PR to the user.
- **A recipe counts once it has run.** Fill every step from the repo and prove it by a run through cleanup, since an unexecuted recipe is a draft.

## Modes

- **Create**, when the project has no verification skill: follow [create](references/create.md).
- **Update**, when it has one: follow [update](references/update.md).

## Output

Name the mode, the skill and files added or changed, the behavior driven, the evidence captured and its path, and any step that could not be run. Update ends in one outcome: **clean** (every feature covered, nothing to change, no branch), **changed** (one branch of proven corrections, listing any feature it could not drive and why), or **blocked** (exactly what stopped coverage).
