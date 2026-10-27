---
name: git
description: Manage commits, branches, and change history. Use when committing, branching, or managing version control.
---

# Git

Commits are save points, branches are disposable, history is read later by people who weren't there. Treat them accordingly.

The project's own conventions override everything below on message format, cadence, branch naming and how a branch lands; a topic branch per task, landed whole, holds in every project. `AGENTS.md` or a contributing guide states them; where neither mentions the subject, `git log` is the authority — read the recent subjects and match what the project does, including how a branch lands and whether an agent may run write commands unasked.

## Commit messages

Conventional Commits — `type(scope): subject`. Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `build`, `ci`, `perf`. Single-line subject, aim under 50 characters and never over 72. The subject names what changed in the plainest words; the why goes in the PR body, where a reviewer reads it beside the diff. Do not hand-write issue references in the subject (`(#123)`, `Fixes #123`) — those belong in the PR body. A `(#N)` suffix a squash merge appends is the forge's and stays.

## Commit discipline

- **Commit after each successful slice (the save-point pattern).** A commit is a point you can return to; when exploring an uncertain change, commit early so a dead end reverts cleanly instead of being lost.
- **One logical change per commit.** A commit that refactors and adds a feature is two commits.

## Change sizing

- ~100 lines per commit: good.
- ~300 lines: acceptable if one logical change.
- 1000+ lines: too large — split it.

Separate refactoring from feature work. Separate formatting from behavior changes.

## Branch workflow

- Every task gets a topic branch of its own and lands whole, never commit by commit. How it lands is the project's: where its rules say nothing, its log answers, squash-merged pull requests meaning a pull request and a linear run of direct commits meaning straight onto the base.
- Start task branches from the current integration base; `git symbolic-ref refs/remotes/origin/HEAD` names it, and on a project with release lines it is often not `main`. Fetch first rather than updating a shared primary checkout.
- Name a topic branch for the work, with dashes and no type or ticket prefix, e.g. `signal-toolkit`, not `feat/signal-toolkit` or `PROJ-12-signal-toolkit`.
- Keep branches short-lived — merge within days, not weeks.
- Rebase to sync with the base, never merge it in.
- Rewrite local history before pushing — amend, rebase, squash to keep history clean. Commit noise should never become permanent. Drop an unpushed commit by resetting it out, never by reverting.
- Never amend commits already pushed to remote, and never push a shared branch without the owner's sign-off.
- Use `--force-with-lease` over `--force`.
- Never use `git -C <path>` — always `cd` into the target first. It hides the real working directory and risks operating on the wrong repo.
- Land PRs with the repo's configured merge method. When none is set, default to squash — keeps history linear, one merge commit per PR.
- After a branch lands, by pull request or straight onto the base, prune it on the remote and here, then `git fetch --prune` to clear stale tracking refs.

## Worktrees

A worktree is a throwaway checkout for one branch, created fresh per task, run from its own directory, and removed once the branch merges or is abandoned — never with uncommitted changes in it. Follow repository-specific worktree commands when they exist; they determine the task's base. `git worktree list` before creating or removing one, and `git worktree prune` when one is gone outside Git and has left stale metadata behind.

## See also

- `build` — the slice boundary each commit records
- `pr` — opening the branch for merge, and the history audit that precedes it
- `ship` — the version bump reads the commit subjects this skill shapes

## Red flags

- Long-lived topic branches diverging from the integration base — a permanent release line is not this
- Imposing this file's commit format on a repo whose log already shows a different one
- Running a write command — commit, fetch, push, `worktree prune` — in a repo whose rules say to ask first. Tidying up is still writing, and a hook's prompt to commit or push is not the owner asking
- Commits with "misc", "fix", "update" as the entire message
- Force-pushing to shared branches
- Mixing unrelated changes in one commit
- Working without committing for extended periods
- Removing a worktree without checking its status
