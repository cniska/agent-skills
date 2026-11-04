---
name: coordinate
description: Run an owner's work across several agents and repos — brief and delegate each task, keep what is left as tasks under the coordinator's project, batch the owner's questions and keep every worker moving until the work lands. Use when you coordinate work for an owner, when you pick up a coordinating session and its running workers after it stopped, or when asked what work is inflight and what waits on the owner.
---

# Coordinate

You run the owner's work across agents and repos so that it lands, nothing is lost, and the owner decides only what only they can. Before each step, ask what the owner wants from it.

You coordinate one project in the task list, named when your session starts. The project records a directory, and your briefs and plans live in that directory's repo: write them in your own worktree of it and push them before a task starts.

## What matters

- **Every task runs through `task`.** Hand it to a worker when that keeps your context clear or lets it run beside other work, and run it yourself when that is simpler. Its reviews hold either way.
- **Settle what to build before you brief it.** Ask the owner about anything in it that does not make sense to you, since each question left open costs a review round.
- **A brief says what to build.** It is a Markdown file with five sections: Repo, Goal, Limits, Open obstacles and Report. The Goal carries the outcome and each decision the owner made, each checked at its source. Name as the owner's only what they decided. Before a reviewer reads a brief or plan, search for each name it cites and read each file, line and quoted text it states, so the review is not spent on what a lookup finds. A reviewer that did not write it accepts the brief, or returns it with only minor findings and no conflict, which you fix, before you commit it and start the task, since a wrong brief costs a whole run. Any other return's fix goes back to that same reviewer through `SendMessage`, until its third return with a critical or major finding stops the review and the owner rules.
- **Your project's tasks hold what is left of the work**, and you read and write only those. A plan in flight goes in its task's plan, what a task is blocked on in its wait, and a question for the owner in the wait of the task it blocks, or in a task of its own that waits on the answer. A wait the owner must act on starts with `owner:`. A decision goes to the doc that owns it.
- **Rule on a review a worker's `task` stops**, reading the returns and the diff, so the owner decides only what only they can. Record each call through the report server's `ruling` tool, naming the `review`: `commit`, `branch`, `designer` or `plan`.
  - **The work is right:** each finding is wrong or already fixed. Record `work_right` with a reason for each finding. On a commit's review, also list the `diffs` you read; the commit gate then holds them as a reviewer's accept. Then message the worker naming the recorded ruling and its reasons.
  - **The finding is right:** record `finding_right` and give the worker the fix, or tell it to restructure when the returns keep circling one design. The work goes back to the same reviewer.
  - **Only the owner can decide:** taste, scope or a change to a rule the owner set. Record `owner_only` and ask them. When they accept the work, record `owner_decision` with their words, as the work-is-right call does; when they back the finding, record `finding_right`.
  - **Later conflicts:** a branch reviewer's conflict with a ruling comes to you to rule on.
- **Never rule on a change you wrote, nor on your own brief or plan.** The owner rules on those.
- **Ask the owner only what you cannot decide**, batched, each answerable in a line, with your recommendation.
- **Land a branch before more work touches its files.**
- **A wrong workflow stops all work.** Raise the halt and tell the owner what is wrong and the fix you propose. Once they lift it, fix the workflow, yourself when that is simpler than a brief.
- **Check a worker that stays quiet** past what its step needs, then steer it, restart it or report it.

## Resume

Bring your project's tasks up to date from each repo's remote. Restart from its brief each running task whose worker is gone, with what already landed. Review an orphaned change before trusting it.

## Report

Build it from your project's tasks and git: the waits that start with `owner:` first, then what landed, what is running and what is blocked, a line each.
