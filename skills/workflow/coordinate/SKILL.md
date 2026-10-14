---
name: coordinate
description: Run and coordinate work across several agents or repos for an owner — delegate each task, keep a ledger, batch the owner's questions and keep every agent moving. Use when you run work across several agents or repos for an owner, or pick up or resume a coordinating session and its workers after it stopped or moved, or when asked for a report on what's in flight (inflight), the status of all work or how to prioritize it.
argument-hint: "<the work>"
---

# Coordinate

Hold work that spans agents or repos so none of it is lost, stranded, or left waiting on the owner without need. Each task itself runs through `task`.

## Rules

1. **Delegate each task to a subagent that loads the `task` skill with the Skill tool**, briefed as [the brief](references/brief.md) says.
2. **Run reviewers as in-process subagents** that did not write the work, never as new cloud sessions.
3. **Follow each repo's push rule, and land before starting more.** A worker lands accepted commits as `task` says. Start no new task in a repo while accepted work sits unlanded there, as its remote shows: land it first, and where landing waits on the owner, ask them for it.
4. **Keep a ledger** at `$AGENT_LEDGER`, or else `agent-skills/ledger.md` under `$XDG_STATE_HOME`, or under `~/.local/state` when that is unset or not absolute, creating its directory. It holds open work per repo, owner decisions, questions waiting on the owner, ideas worth keeping but not acting on now, open obstacles (each defect in a tool, hook or gate a worker stopped at, until it is fixed), a running line per worker naming its repo, worktree and brief, the path to the [experiment record](references/experiments.md) beside it, and any plan that spans sessions or agents. The session running the agents rewrites it whenever a worker starts or stops and at every report it gives: a worker's running line and its brief, filed beside the ledger, are committed and pushed before the worker starts, so a session that dies loses nothing; once its work lands, both go, since `git log` holds it. A session that only reports leaves it unchanged and says which ledger lines git contradicts. Where the file sits in a git checkout, commit and push the ledger, its briefs and its experiment record alone, under that repo's rules.
5. **Keep every plan in the ledger's repo or the work's repo**, never only in a message or a temp path another machine cannot reach. Each worker works in its own worktree, never a primary checkout, so what it leaves is findable and its own.
6. **Check in on an agent that has gone quiet** for longer than its step needs: read its latest output, then steer it, restart it, or report it, and update the ledger.
7. **Take every choice you have a clear recommendation for**, design tradeoffs included, such as push timing or slicing, and name each in the report. When unsure, or when an owner idea or design question takes more than a line or two to settle, get a `powerful`-tier read through `second-opinion` first, from a `researcher` agent where the host can start one, and file what it returns as a proposal, an idea in the ledger, or a drop with its reason. Ask the owner only about product tradeoffs and what you cannot answer.
8. **Coach each task a worker hands back.** Apply the workflow review its hand-back carries, or where it carries none, run `workflow-review` over that worker's task in a fresh agent; apply each proposal except conflicts, which go to the owner, and open an [experiment](references/experiments.md) for each change where that file calls for one.

## Resume

Resume a coordinating session, with its ledger, its workers and what they left, after compaction, in a fresh session, or on another machine, in the cloud or under another account, as [resume](references/resume.md) says.

## Report

Report in [its shape](references/report.md), with the owner's questions batched from every worker.

## See also

- `task` — the route each delegated task runs
- `design-review` — what the reviewers judge
- `second-opinion` — the read to get before asking the owner
- `workflow-review` — coaches each task, and checks each due experiment and proposes its outcome

## Red flags

- A task worked in the coordinator's own context instead of delegated
- A reviewer started as a new cloud session
- A worker's commit stacked on one not yet accepted
- A new task started in a repo where accepted work sits unlanded
- A plan or brief held only in a message or a temp path
- A worker started before its running line is in the ledger and its brief committed beside it, or working in a primary checkout
- A resume that reads the ledger unpulled, trusts orphaned changes unreviewed, or reports before rewriting the ledger
- A report from the session running the agents that leaves the ledger stale
- An owner question about a choice the coordinator could recommend, or one asked before a second opinion
- A worker's reported obstacle missing from the ledger, or left out of a brief whose work it touches
- A quiet agent left unchecked
- A report built from memory rather than the ledger and git
- Owner questions placed below status
- Work called pushed without checking the remote
- A workflow change applied without an `open` line in the experiment record or a reason in the report that no signal can read it, or an experiment left open past its check date
