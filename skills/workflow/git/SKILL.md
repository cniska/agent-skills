---
name: git
description: Manage commits, branches and landings in git so each task lands as one topic branch with a readable history. Use when committing, branching, rewriting unpushed history, landing a branch or managing worktrees.
---

# Git

Commits are save points, a branch lasts as long as its task, and people who weren't there read the history later. Keep each of them fit for that use.

The project's own conventions win on message format, cadence, branch naming and how a branch lands. Its `AGENTS.md` or contributing guide states them. Where neither covers a subject, read the recent `git log` and match what the project does, including how a branch lands and whether an agent may run write commands unasked. A topic branch per task, landed whole, holds in every project.

## Commits

- **Write the subject as a Conventional Commit**, `type(scope): subject`, with one of `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `build`, `ci` or `perf`. Keep it to one line, under 50 characters where it fits and never over 72, naming what changed in the plainest words. The why goes in the PR body, where a reviewer reads it beside the diff.
- **Commit after each slice that passes.** A commit is a point to return to, so commit early on an uncertain change and a dead end reverts cleanly.
- **Make each commit one logical change.** Separate a refactor from the feature it enables, and formatting from behavior.
- **Size commits for review.** About 100 lines is good, and about 300 is fine for one logical change. Split anything of 1000 lines or more.

## Branches

- **Give every task its own topic branch and land it whole.** How it lands is the project's choice. Where its rules say nothing, its log answers: squash-merged pull requests mean a pull request, and a linear run of direct commits means straight onto the base.
- **Start from the current integration base**, which on a project with release lines is often not `main`. Fetch the base instead of updating a shared primary checkout.
- **Name the branch for the work**, with dashes and no type or ticket prefix: `signal-toolkit`, not `feat/signal-toolkit`.
- **Merge within days.** A branch that lives for weeks drifts from its base.
- **Sync with the base by rebasing onto it.** A merge of the base into the branch leaves merge commits in history.
- **Clean up local history before pushing**: amend, rebase and squash so commit noise never becomes permanent. Drop an unpushed commit by resetting it out, since a revert leaves both commits behind.
- **Once a commit is pushed, fix it with a new commit.** Push a shared branch only with the owner's sign-off.
- **Land a pull request with the repo's configured merge method**, or a squash where none is set, for a linear history with one commit per pull request.
- **After a branch lands, prune it** on the remote and locally, then fetch with prune to clear stale tracking refs.

## Worktrees

A worktree is a checkout for one task's branch: create it fresh per task, work from its own directory, and follow the repo's worktree commands where it has them, since they set the task's base. Remove it once its branch lands or is abandoned, after its changes are committed or knowingly discarded. List worktrees before creating or removing one, and prune the stale metadata of one deleted outside git.
