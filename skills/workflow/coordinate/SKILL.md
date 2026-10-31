---
name: coordinate
description: Run and coordinate work across several agents or repos for an owner — delegate each task, keep a ledger, batch the owner's questions and keep every agent moving. Use when you run work across several agents or repos for an owner, or pick up or resume a coordinating session and its workers after it stopped or moved, or when asked for a report on what's in flight (inflight), the status of all work or how to prioritize it.
argument-hint: "<the work>"
---

# Coordinate

You run the owner's work across agents and repos so that it lands, nothing is lost, and the owner is asked only what only they can decide. Before each step, ask what the owner actually wants from it. Doing that well matters more than any rule below.

## Rules

1. **Delegate a task that needs its own branch** to a worker that runs it through `task`. Do small things yourself, such as a question, a lookup or a fix to your own files.
2. **Brief the worker on what to build, never how.** A brief is a short Markdown file in the ledger's repo with five sections: Repo, Goal, Limits, Open obstacles and Report. The Goal holds the outcome and each decision the owner made, in your own words, each checked at its source. Never present your own idea as the owner's. Have a fresh reviewer check what the brief asks for, then commit it and start the task before the worker starts.
3. **Keep the ledger to what is left of the work**: plans in flight, what a task is blocked on, and questions waiting on the owner. Tasks live in the task tool. A decision goes to its home, such as a spec, `AGENTS.md`, docs or a skill, never to the ledger.
4. **Decide what you can, and ask the owner only what you cannot.** Batch their questions, each answerable in a line, with your recommendation.
5. **Land a branch before starting more work on its files.** Count a task done only when `task` would.
6. **When the workflow turns out to be wrong, stop the work it drives** and fix the workflow first, or ask the owner.
7. **Workflow changes go to the owner.** Apply no proposal from a workflow review, and add no rule to a skill, without their yes.
8. **Check on a worker that has gone quiet** for longer than its step needs, then steer it, restart it or report it.

## Resume

Pull the ledger's repo, then read the ledger, the task list and each repo's remote. For each of your running tasks, check whether its work landed, whether its worker is still running, or whether it needs to be restarted from its brief with what already landed. Review any orphaned change before trusting it. Rewrite the ledger before the first report.

## Report

Build the report from the ledger, the task list and git, never from memory. List what waits on the owner first, then what landed, what is running and what is blocked, each in a line.

## See also

- `task`: the route each worker runs
- `second-opinion`: an independent read before a costly call
- `workflow-review`: what should change in the workflow, for the owner to decide

## Red flags

- A brief, rule or report written without first asking what the owner wants from it
- Your own idea stated as the owner's decision
- A rule added to a skill to patch one slip
