---
name: pr
description: Create a pull request with review and verify. Use when the branch is ready to merge.
---

# PR

Two modes: **Create** (default) — push and open a PR; **Update** — rewrite an existing PR's description without pushing. Detect which by checking for an open PR on the current branch before acting.

## Conventions

- Title: the repo's commit subject rules, which win; without them, Conventional Commit format (`type(scope): description`), under 60 chars, no trailing period
- Body: follow `.github/pull_request_template.md` if it exists — fill in each section, do not add or remove sections
- Keep it short — the fewest bullets that convey the change. Omit anything a reviewer would infer from the diff: mechanical steps, refactors in service of the main change, file moves, renames
- Bullets: high-signal plain English only; say what changed and why it is safe, never how the work unfolded — no code blocks, no prose paragraphs, no implementation bookkeeping
- Motivation: optional and brief (1-2 sentences); include only when the *why* isn't obvious from the summary
- Tracker link: when the branch's work belongs to an issue in the project's tracker, end the body with it as a clickable link: `Fixes #23`, or `Fixes PROJ-23` with the key linked to the issue's URL. Use a closing word only when merging completes the issue; otherwise a non-closing one (`Part of`). The repo's own convention (its PR template, its tracker docs) wins

## Workflow

1. **Check preconditions** (all must pass before continuing):
   - working directory is clean
   - branch has commits ahead of the base branch
   - project verification passes
2. **Have `review` accept the branch** as it stands, by a fresh agent, unless it already has:
   - if it returns any finding, stop and report them — do not create the PR; where it reports through a tool, take its verdict and findings from the stored report, not its closing message
3. **Gather context**:
   - read `.github/pull_request_template.md` if it exists
   - read the branch's commits and its full diff against the base branch
   - find the associated issue: an issue key in the branch name or commits, or a search of the project's tracker
4. **Audit the commits** (`/pr` opens a PR; it does not clean up history for you — fix it here):
   - every commit follows the project's commit conventions (`AGENTS.md` / `CONTRIBUTING` / the `git`
     skill), including **one logical change per commit**
   - if any commit violates, **stop and fix the history first** (split/reword per the `git` skill),
     then re-audit — do not open the PR on non-compliant commits
5. **Draft the PR**:
   - infer a title from the commits and diff
   - fill in the template body (or use a sensible default structure)
   - render the title and body in the conversation and wait for approval — do not push before sign-off
6. **Push the branch** unless the remote already holds every local commit
7. **Create the PR** with the approved title and body
8. **Return only the PR URL**

## See also

- `writing` — voice and plain wording for the description
- `git` for commit conventions and rewriting history before push
- `review` for the findings that hold a PR back
- `doc-review` for user-facing drift checks before merge
