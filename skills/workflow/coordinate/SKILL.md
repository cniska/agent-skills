---
name: coordinate
description: Run and coordinate work across several agents or repos for an owner — delegate each task, keep a ledger, batch the owner's questions and keep every agent moving. Use when you run work across several agents or repos for an owner, or pick up or resume a coordinating session and its workers after it stopped or moved, or when asked for a report on what's in flight (inflight), the status of all work or how to prioritize it.
argument-hint: "<the work>"
---

# Coordinate

Hold work that spans agents or repos so none of it is lost, stranded, or left waiting on the owner without need. Each task itself runs through `task`.

## Rules

1. **Delegate each task to a `worker` agent where the host can start one, else to a subagent that loads the `task` skill with the Skill tool**, briefed as [the brief](references/brief.md) says. A task is one branch that lands as a whole. Work that needs more branches is that many tasks. Start a test-running worker only while the machine's one-minute load average is below twice its core count; at or over that cap, hold it unstarted and read the load again before starting it.
2. **Run reviewers as in-process subagents** that did not write the work, never as new cloud sessions, and show the owner only screenshots the worker captured through the project's verify skill and a fresh agent accepted through `ui-review`, a `designer` where the host can start one. Look at each one yourself beside its reference capture before you forward it, and send any difference its task did not ask for back to its worker, or to a new task when the worker is gone. Commit only in the ledger's repo, except a release's commit and tag in the repo it releases, and put each of your own commits through `task`'s per-commit review, so anything new goes in a commit of its own. The review of a brief or plan you write judges what it asks for: the outcome, the scope, each decision it settles, whether the worker can build from it, and any claim false where it is defined; how the worker builds it is left to the worker's own reviews, and its reviewer reports it neither as a finding nor as a follow-up.
3. **Land a branch before starting more on its files, and recheck it against its rules before it lands.** Start no new task on files that a repo's unlanded branch touches, as its branches and remote show: land that branch first, and where landing waits on the owner, ask them for it. A task on other files of the same repo may start beside it. Recheck each unlanded branch of your own workers before you hand it to the owner, or to a worker or new task sent to land it, and each one a running worker holds whenever you change or reinstall the skills or agent definitions, in a live session as on resume. Recheck it as current rules in `principles` says: a change it finds sends the branch back to its worker, or to a new task when the worker is gone, for re-review under the current rule, and so does a source that cannot be read.
4. **Keep a ledger**, a TOON file, at `$AGENT_LEDGER`, or else one per project at `agent-skills/<project>/ledger.toon` under `$XDG_DATA_HOME`, or under `~/.local/share` when that is unset or not absolute, where `<project>` is the repo's git common directory without a trailing `/.git`, or outside git the project's directory, with each `/` turned to `-`, so every worktree of a repo shares it; create its directory. To keep a project's ledger in a pushed repo, set `AGENT_LEDGER` in that project's local settings, never in user settings, which every project reads. Where the ledger's repo keeps a ledger schema, the ledger follows it. Its root key `shared` may hold the path, absolute or relative to the ledger's directory, of one shared file that several coordinators' ledgers name, for work they share, such as owner setup still to do that no task waits on, and never for a rule or decision; the ledger's folder is that shared file's directory where it names one, else the ledger's own. The ledger holds only what is left of work, which comes and goes, each row under the project it belongs to: each plan in flight that spans sessions or agents, what a running task is blocked on, each question waiting on the owner, and each workflow review proposal the owner accepted that rule 8 keeps. It never holds a rule, a decision or a lesson, and never queued or running work. Put a rule, decision or lesson at its home, or queue a task for that: a skill only when it holds in any project and two independent sessions saw its failure, and a lesson only as a proposal rule 8 handles, else the project's `AGENTS.md`, spec or docs. A one-off correction is fixed in its work and written nowhere. An idea worth keeping but not acting on now goes to the ideas file the project's rules name, else to an `IDEAS.md` in the ledger's folder. An open obstacle, a defect in a tool, hook or gate a worker stopped at, becomes a fix task whose goal carries the workaround. An obstacle with no fix goes to its project's `AGENTS.md`, or, when it spans projects, to the instruction file of the ledger's repo, else, where the ledger is in no repo, to the `AGENTS.md` of each project it touches. Queued and running work, the in-flight list, lives in a task tool, which coordinating requires: each queued task waits there until its worker starts, and each worker's task is started with its repo and brief, closed as done with the commits it landed, or dropped with a reason when its work is given up. Queue each owner decision that needs work as a task when the owner gives it, as rule 8 queues a follow-up; one held for an event, such as an app's first run, is queued now, waiting on that event. Your workers are those whose brief is filed as this rule says; resume and report cover only those. With a shared file, read it with your ledger, write there only the shared work it holds, and rewrite only your own ledger. The session running the agents rewrites its ledger whenever its state changes and at every report it gives. A worker's brief, filed in the ledger's folder and, where several ledgers share that folder, named for your ledger's file name without its extension followed by `-<task>`, is committed and pushed, and its task started, before the worker starts, so a session that dies loses nothing; once its work lands and every CI run on the commit it landed is green, its task closes as done and its brief goes, since `git log` holds it; once its work is given up, its task is dropped with the reason and its brief goes. A session that only reports leaves it unchanged and says which ledger entries git contradicts. Where the file sits in a git checkout, commit and push the ledger, the shared file and its briefs alone, under that repo's rules.
5. **Keep every plan in the ledger's repo or the work's repo**, never only in a message or a temp path another machine cannot reach. Each worker works in its own worktree, never a primary checkout, so what it leaves is findable and its own.
6. **Check in on an agent that has gone quiet, and stop each one a workflow defect touches.** When an agent is quiet for longer than its step needs, read its latest output, then steer it, restart it, or report it, and update the ledger. When you or the owner find a defect in the workflow behind work in flight, such as a brief, a reviewer, a skill or an agent definition, stop every worker it touches at once, never at a safe point, record in the ledger that each one's task is blocked on the fix, and restart none until the fix has landed, has reached the sessions that will run the work, and that worker's brief is rewritten under the fix.
7. **Take every choice about running the work that you have a clear recommendation for**, such as push timing or slicing, and name each in the report. Leave each design choice to the worker and its reviews. When unsure, or when an owner idea or design question takes more than a line or two to settle, get a `powerful`-tier read through `second-opinion` first, from a `researcher` agent where the host can start one, and file what it returns as a proposal, an idea in the ideas file rule 4 names, or a drop with its reason. Ask the owner only about product tradeoffs and what you cannot answer.
8. **Check each task once its worker hands back or stops, and put each workflow review to the owner.** On a hand-back, check that every CI run on the commit it landed is green, and send a red one back to the worker, or to a new task when the worker is gone; read the worker's report from the report tool's stored report where it reported through one; otherwise, where no hand-back came, read the report the worker stated in its transcript, through the session record where one is installed. Queue each follow-up the worker's report names where the review report in `principles` sends it, or drop it with its reason in your report. Put each workflow review's proposals to the owner, wherever that review runs, a revert or trim included, and apply only the ones the owner accepts. This falls to the coordinator whose ledger covers the skills and tools, or, where no ledger covers them, to the coordinator the review reaches. Any other coordinator neither proposes nor applies a workflow change, and forwards each one that reaches it to that coordinator. Keep each applied proposal in the ledger, its review's date and its Where and Change beside the sha of the commit that landed it, until a later review judges it keep, revert or trim or sends it to the owner as unproven; then the row goes, since `git log` keeps it.

## Resume

Resume a coordinating session, with its ledger, its workers and what they left, after compaction, in a fresh session, or on another machine, in the cloud or under another account, as [resume](references/resume.md) says.

## Report

Report in [its shape](references/report.md), with the owner's questions batched from every worker.

## See also

- `task` — the route each delegated task runs
- `design-review` and `doc-review` — what the reviewers judge, on code and on docs
- `second-opinion` — the read to get before asking the owner
- `principles` — verify at the source, for each claim a brief or a recommendation to the owner states, the review report, for where a worker's follow-ups go, and current rules, for rule 3's recheck
- `code-writing` — bundles the bounded-run script a brief names for a worker's suite or long command
- `workflow-review` — proposes the workflow changes a window of work shows, and reverts of those that failed to help

## Red flags

- A task worked in the coordinator's own context instead of delegated
- A worker that runs tests started while the load average is at or over twice the core count
- A reviewer started as a new cloud session
- A screenshot shown to the owner before a fresh `ui-review` accepted it, or before you looked at it beside its reference capture
- A worker's commit stacked on one not yet accepted
- A new task started on files an unlanded branch in the same repo touches
- A branch handed to the owner, or landed, after a skill or agent definition that wrote or judged it changed, with no re-review under the current rule
- A plan or brief held only in a message or a temp path
- A brief that describes a watchdog or a bound instead of naming the tool
- A worker started before its brief is committed in the ledger's folder and its task started, or working in a primary checkout
- A resume that reads the ledger unpulled, trusts orphaned changes unreviewed, or reports before rewriting the ledger
- A report from the session running the agents that leaves the ledger stale
- An owner question about a choice the coordinator could recommend, or one asked before a second opinion
- A worker's reported obstacle left with no fix task and no home, or left out of a brief whose work it touches
- A quiet agent left unchecked
- A report built from memory rather than the ledger, the in-flight list and git
- Queued or running work kept in the ledger
- A rule, decision or lesson written into the ledger or its shared file instead of its home
- Owner questions placed below status
- Work called pushed without checking the remote
- A hand-back counted as landed while its CI is red or still running
- An owner decision that needs work recorded without a task, or held for an event instead of queued waiting on it
- A follow-up from a worker's report left unqueued, or dropped without its reason in the report
