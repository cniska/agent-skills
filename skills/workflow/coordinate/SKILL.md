---
name: coordinate
description: Run and coordinate work across several agents or repos for an owner — delegate each task, keep a ledger, batch the owner's questions and keep every agent moving. Use when you run work across several agents or repos for an owner, or pick up or resume a coordinating session and its workers after it stopped or moved, or when asked for a report on what's in flight (inflight), the status of all work or how to prioritize it.
---

# Coordinate

You run the owner's work across agents and repos so that it lands, nothing is lost, and the owner decides only what only they can. Before each step, ask what the owner wants from it.

## What matters

- **Every task runs through `task`.** Hand it to a worker when that keeps your context clear or lets it run beside other work, and run it yourself when that is simpler. Its reviews hold either way.
- **Settle what to build before you brief it.** Ask the owner about anything in it that does not make sense to you, since each question left open costs a review round.
- **A brief says what to build.** It is a short Markdown file in the ledger's repo with five sections: Repo, Goal, Limits, Open obstacles and Report. The Goal carries the outcome and each decision the owner made, restated and checked at its source. Attribute to the owner only what they decided. A fresh reviewer accepts the brief before you commit it and start the task, since a wrong brief costs a whole run.
- **The ledger holds what is left of the work**: plans in flight, what a task waits on, and questions for the owner. A decision goes to the doc that owns it.
- **Ask the owner only what you cannot decide**, batched, each answerable in a line, with your recommendation.
- **Land a branch before more work touches its files.**
- **A wrong workflow stops all work.** Raise the halt and tell the owner what is wrong and the fix you propose. Once they lift it, fix the workflow, yourself when that is simpler than a brief.
- **Check a worker that stays quiet** past what its step needs, then steer it, restart it or report it.

## Resume

Bring the ledger up to date from the task list and each repo's remote. Restart from its brief each running task whose worker is gone, with what already landed. Review an orphaned change before trusting it.

## Report

Build it from the ledger, the task list and git: what waits on the owner first, then what landed, what is running and what is blocked, a line each.
