---
name: git
description: Manage commits, branches, and change history. Use when committing, branching, or managing version control.
---

# Git

Commits are save points, branches are disposable, history is read later by people who weren't there. Treat them accordingly.

The project's own conventions override everything below, and that includes cadence and branching, not just message format. `AGENTS.md` or a contributing guide states them; where neither mentions the subject, `git log` is the authority — read the recent subjects and match what the project does, including whether it branches at all and whether an agent may run write commands unasked.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) — `type(scope): subject`. Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `build`, `ci`, `perf`. Single-line subject, aim under 50 characters and never over 72. Do not hand-write issue references in the subject (`(#123)`, `Fixes #123`) — those belong in the PR body. A `(#N)` suffix a squash merge appends is the forge's and stays.

## Commit discipline

- **Commit after each successful slice (the save-point pattern).** A commit is a point you can return to; when exploring an uncertain change, commit early so a dead end reverts cleanly instead of being lost.
- **One logical change per commit.** A commit that refactors and adds a feature is two commits.
- **Explain intent, not mechanics.** Describe why the change matters, not what files were touched.

## Change sizing

- ~100 lines per commit: good.
- ~300 lines: acceptable if one logical change.
- 1000+ lines: too large — split it.

Separate refactoring from feature work. Separate formatting from behavior changes.

## Branch workflow

- Branch when the change needs review or outlives a sitting. A small fix in a repo whose own rules allow it goes straight onto the integration branch — a branch and a PR for a one-line change is ceremony.
- Start task branches from the current integration base; `git symbolic-ref refs/remotes/origin/HEAD` names it, and on a project with release lines it is often not `main`. Fetch first rather than updating a shared primary checkout.
- Use short topic branch names without type prefixes, e.g. `signal-toolkit`, not `feat/signal-toolkit`.
- Keep branches short-lived — merge within days, not weeks.
- Rewrite local history before pushing — amend, rebase, squash to keep history clean. Commit noise should never become permanent.
- Never amend commits already pushed to remote.
- Use `--force-with-lease` over `--force`.
- Never use `git -C <path>` — always `cd` into the target first. It hides the real working directory and risks operating on the wrong repo.
- Land PRs with the repo's configured merge method. When none is set, default to squash — keeps history linear, one merge commit per PR.
- After a PR merges, prune the branch locally and on the remote, then `git fetch --prune` to clear stale tracking refs.

## Worktrees

Where a project uses them: a worktree is a throwaway checkout for one branch, created fresh per task, run from its own directory, and removed once the branch merges or is abandoned — never with uncommitted changes in it. Follow repository-specific worktree commands when they exist; they determine the task's base. `git worktree list` before creating or removing one, and `git worktree prune` when one is gone outside Git and has left stale metadata behind.

## See also

- `build` — the slice boundary each commit records
- `pr` — opening the branch for merge, and the history audit that precedes it
- `ship` — the version bump reads the commit subjects this skill shapes

## Red flags

- Long-lived topic branches diverging from the integration base — a permanent release line is not this
- Imposing this file's commit format on a repo whose log already shows a different one
- Commits with "misc", "fix", "update" as the entire message
- Force-pushing to shared branches
- Mixing unrelated changes in one commit
- Working without committing for extended periods
- Removing a worktree without checking its status
