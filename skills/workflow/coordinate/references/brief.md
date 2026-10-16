# Brief

A brief is the worker's whole context: it starts with none of yours. Write it so a stranger could act on it alone — no "as discussed", no pointer to this conversation.

## What it holds

- **The repo and the goal**, and every decision the owner settled, stated as the rule, not its history.
- **Each defect the task fixes, as it was seen**: the command run and what it printed; the goal states done as proof of the behavior, not of the cause.
- **The repo's rules to follow**: point at its `AGENTS.md` or `CLAUDE.md` and name only the rules this task is likely to trip. For a repo other than the one this session started in, name its instruction file and each of its project skills by path, and tell the worker to read them: a worker starts in this session's project and loads neither.
- **Each limit with what it still allows**: a limit such as "stay out of other repos" names what it leaves open, such as reading them for a sibling to clone, so it cuts no step the work needs.
- **Where the plan lives**: a path in the repo or the ledger, never a temp path or this message.
- **Where it works**: a worktree of its own, never a primary checkout, and a temp folder of its own named for its task, never a shared scratchpad's root, so parallel workers cannot overwrite each other's files.
- **The open obstacles that touch the work**, from the ledger as it stands when the worker starts, not when the brief was written: each defect in a tool, hook or gate it may hit, so the worker stops and reports at it rather than working around it.
- **How reviews get recorded**: who runs the reviewer, and what a commit gate needs before the worker may commit.
- **How the work lands**: the task's branch, landed whole by the repo's own route, and whether the worker or the coordinator lands it.
- **What to report, and how short**: the outcome, commits, checks, choices the owner did not make, and anything left open, in a line budget.

Leave out what the repo or `git log` already holds; link it.

Every claim about existing code, repo state or a file's wording goes in only once checked, as verify at the source in `principles` says, and is marked a guess otherwise. A fact a researcher or a doc supplied goes in as its quote, with the citation, not reworded.

## How to deliver it

File the brief in the ledger's folder under the name rule 4 gives and start its task before the worker starts, as rule 4 says; the delivered brief is that file's text.

- **A subagent of this session**: the brief is its whole prompt.
- **Another session on this machine**: the brief is the message that starts it; it reads this machine's files, so link them rather than paste them.
- **A cloud session**: it cannot reach this machine's files, so the brief carries what it needs, and the worker pushes before it stops.
