# Brief

A brief is the worker's whole context: it starts with none of yours. Write it so a stranger could act on it alone — no "as discussed", no pointer to this conversation.

## What it holds

- **The repo and the goal**, and every decision the owner settled, stated as the rule, not its history.
- **The repo's rules to follow**: point at its `AGENTS.md` or `CLAUDE.md` and name only the rules this task is likely to trip.
- **Where the plan lives**: a path in the repo or the ledger, never a temp path or this message.
- **How reviews get recorded**: who runs the reviewer, and what a commit gate needs before the worker may commit.
- **How the work lands**: commit, push or pull request, on which branch, and whether the worker or the coordinator does it.
- **What to report, and how short**: the outcome, commits, checks, choices the owner did not make, and anything left open, in a line budget.

Leave out what the repo or `git log` already holds; link it.

## How to deliver it

- **In-process subagent**: the brief is the Agent tool's prompt.
- **Local session, on this machine or under Remote Control**: send it with SendMessage, or the remote `send_message`.
- **Cloud session**: send it with `send_message`, and say the session cannot reach this machine's files, so the brief carries what it needs and the worker pushes before it stops.
