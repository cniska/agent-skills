# Brief

A brief is the worker's whole context: it starts with none of yours. Write it so a stranger could act on it alone — no "as discussed", no pointer to this conversation. Word it by `writing`'s medium for instructions an agent follows. Keep it short: it says what to build and leaves out how. A how in a brief limits the worker, and the worker's route and its reviewers catch what goes wrong in how the work is built, so a brief does not head it off.

## Its sections

Every brief has these five sections, in this order, and no others, so briefs stay consistent.

- **Repo**: its path, and an instruction to read its `AGENTS.md` or `CLAUDE.md`, since a worker started from another project loads neither.
- **Goal**: the outcome the work achieves, every decision the owner settled on it, any copy the owner set, the path of the plan that sets it where one does, and each defect the task fixes as it was seen, the command run and what it printed. State each decision as the outcome it settles, not its history, in your own words checked at their source as `principles` says. State done as proof of the behavior, not of the cause. Leave how the work is built and judged to the worker and its reviews: its design, its implementation, and the requirement, skill or doc text written for it. Name code only to point at where to look, never to say what to build.
- **Limits**: the scope only, each limit with what it still allows, such as reading other repos for a sibling to clone under "stay out of other repos", so it cuts no step the work needs.
- **Open obstacles**: each defect in a tool, hook or gate the work may hit that `task` does not cover, copied from where rule 4 puts it as it stands when the worker starts, so the worker stops and reports at it rather than working around it.
- **Report**: what the coordinator needs back, such as the landed commit, each choice the owner did not make and anything left open.

Leave out what `task`, the repo or `git log` already holds, such as reviewer routing, re-reviews, worktrees, temp folders, bounds on a suite, landing and how a check is proven able to fail. Link a file the repo holds rather than restate it. Cite a file by a quote, heading or symbol, never a line number, since line numbers move with each edit.

Every claim about existing code, repo state or a file's wording goes in only once checked, as verify at the source in `principles` says, and is marked a guess otherwise. A fact a researcher or a doc supplied goes in as its quote, with the citation, not reworded.

## How to deliver it

File the brief in the ledger's folder under the name rule 4 gives, and start its task in the task tool before the worker starts, as rule 4 says; the delivered brief is that file's text.

- **A subagent of this session**: the brief is its whole prompt.
- **Another session on this machine**: the brief is the message that starts it; it reads this machine's files, so link them rather than paste them.
- **A cloud session**: it cannot reach this machine's files, so the brief carries what it needs, and the worker pushes before it stops.
