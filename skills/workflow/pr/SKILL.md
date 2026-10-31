---
name: pr
description: Create a pull request once `review` accepts the branch, or rewrite the description of the one already open, with a title and body the owner approves first. Use when a branch is ready to merge through a pull request.
---

# PR

Push the branch and open a pull request for it. When a pull request is already open on the branch, rewrite its description instead and push nothing. Check for an open one on the current branch first: with one open, run only steps 3 and 5, then replace its description with the approved one.

## Title and body

- **Title:** the repo's commit subject rules, which win. Without them, a Conventional Commit subject, `type(scope): description`, under 60 characters.
- **Body:** when `.github/pull_request_template.md` exists, fill in each of its sections as given. Otherwise use a short default structure.
- **Bullets:** the fewest that convey the change, in plain English, each saying what changed and why it is safe. Leave out what a reviewer infers from the diff, such as mechanical steps, refactors that serve the main change, file moves and renames.
- **Motivation:** one or two sentences, only when the why is not obvious from the bullets.
- **Tracker link:** when the branch's work belongs to an issue in the project's tracker, end the body with a clickable link to it: `Fixes #23`, or `Fixes PROJ-23` with the key linked to the issue's URL. Use a closing word only when merging completes the issue, and a non-closing one such as `Part of` otherwise. The repo's own convention, in its template or tracker docs, wins.

## Workflow

1. **Check the preconditions.** All must hold before going on:
   - the working directory is clean
   - the branch has commits ahead of the base branch
   - the project's verification passes
2. **Have `review` accept the branch** as it stands, by a fresh agent, unless it already has. When it returns any finding, stop and report the findings without creating the pull request. When the review reports through a tool, take its verdict and findings from the stored report, not from its closing message.
3. **Gather context:**
   - the pull request template, if one exists
   - the branch's commits and its full diff against the base branch
   - the associated issue: an issue key in the branch name or commits, or a search of the project's tracker
4. **Audit the commits.** Every commit follows the project's commit conventions, from its rules file, `CONTRIBUTING` or the `git` skill, with one logical change per commit. When any commit breaks them, fix the history first as the `git` skill says, then audit again.
5. **Draft the title and body** from the commits and diff, worded as `writing` says. A chart in the body follows `docs-writing`. Show the title and body in the conversation and wait for the owner's approval.
6. **Push the branch** once approved, unless the remote already holds every local commit.
7. **Create the pull request** with the approved title and body.
8. **Return only the pull request's URL.**
