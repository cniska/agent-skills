# Brief

A brief is the worker's whole context: it starts with none of yours. Write it so a stranger could act on it alone — no "as discussed", no pointer to this conversation. Word it by `writing`'s medium for instructions an agent follows.

## What it holds

- **The repo and the goal**, every decision the owner settled and every design choice rule 7 has you take, each stated as the outcome it settles, not its history; the requirement, skill or doc text written for it is the worker's, like every other choice of how the change is built, which the worker's `design-review` judges, except an owner's own words, quoted as the owner's.
- **Each defect the task fixes, as it was seen**: the command run and what it printed; the goal states done as proof of the behavior, not of the cause.
- **Another repo's rules**: for a repo other than the one this session started in, name its instruction file and each of its project skills by path, and tell the worker to read them: a worker starts in this session's project and loads neither.
- **Each limit with what it still allows**: a limit such as "stay out of other repos" names what it leaves open, such as reading them for a sibling to clone, so it cuts no step the work needs.
- **Where the plan lives**: a path in the repo or the ledger, never a temp path or this message.
- **Its temp folder**: one of its own named for its task, never a shared scratchpad's root.
- **The bound on a suite or a long command**: the bounded-run script the `code-writing` skill bundles, so no worker writes its own.
- **The open obstacles that touch the work and that `task` does not cover**, from where rule 4 puts them, as they stand when the worker starts, not when the brief was written: each defect in a tool, hook or gate it may hit, so the worker stops and reports at it rather than working around it.
- **What to report, and how short**: the outcome, commits, checks, choices the owner did not make, and anything left open, in a line budget.

Leave out what `task`, the repo or `git log` already holds, such as reviewer routing, diff files, re-reviews, parking a commit, worktrees, landing and how a check is proven able to fail, which proven able to fail in `principles` holds, so a brief names that principle rather than a method; link a file the repo holds rather than restate it. Cite a file by a quote, heading or symbol, never a line number, since line numbers move with each edit.

Every claim about existing code, repo state or a file's wording goes in only once checked, as verify at the source in `principles` says, and is marked a guess otherwise. A fact a researcher or a doc supplied goes in as its quote, with the citation, not reworded.

## How to deliver it

File the brief in the ledger's folder under the name rule 4 gives, and start its task in the task tool before the worker starts, as rule 4 says; the delivered brief is that file's text.

- **A subagent of this session**: the brief is its whole prompt.
- **Another session on this machine**: the brief is the message that starts it; it reads this machine's files, so link them rather than paste them.
- **A cloud session**: it cannot reach this machine's files, so the brief carries what it needs, and the worker pushes before it stops.
