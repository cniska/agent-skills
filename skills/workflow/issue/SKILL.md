---
name: issue
description: Create a GitHub issue from a short description, checking for duplicates and filing it once the user approves the draft. Use when asked to file a bug, feature request or task as an issue.
---

# Issue

Turn a short description into a GitHub issue that anyone reading the repo can act on. The issue says what is wanted and why, and leaves how to build it to the branch that does.

## Conventions

The repo's own issue template, labels and commit subject rules win over these defaults.

- **Title:** `type(scope): description`, under 60 characters, ending without a period.
- **Label:** `enhancement` for a feature, `bug` for a bug.
- **Body:** four `##` sections in order, **What would you like?**, **Motivation**, **Proposed approach** and **Scope**. Each holds one to three short paragraphs of plain prose, and a single sentence is fine. Scope alone is a flat bullet list of the affected areas.
- **What and why:** describe the outcome and its motivation in plain words. Leave code, file-level detail and the implementation plan to the branch.
- **Self-contained:** the issue stands alone for a reader who has only the repo. Spell each point out in full or drop it, in place of a link to a private or local doc such as a planning file, or internal shorthand such as `P1` or `RC4`.

## Workflow

1. **Understand the idea.** Read the user's description, and ask when its intent or scope is unclear.
2. **Check for duplicates** among the open issues.
3. **Draft** the title, label and body as the conventions say, the body worded as `writing` says.
4. **Show the draft** to the user and wait for approval.
5. **Create the issue** with the approved title, label and body.
6. **Return only the issue URL.**
