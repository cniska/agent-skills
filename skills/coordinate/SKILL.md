---
name: coordinate
description: Run work across several agents or repos for an owner — delegate each task, keep a ledger, batch the owner's questions and keep every agent moving. Use when you run or resume work across several agents or repos for an owner, or when asked for a report on what's in flight (inflight), the status of all work or how to prioritize it.
argument-hint: "<the work>"
---

# Coordinate

Hold work that spans agents or repos so none of it is lost, stranded, or left waiting on the owner without need. Each task itself runs through `task`.

## Rules

1. **Delegate each task to a subagent that loads the `task` skill with the Skill tool**, briefed as [the brief](references/brief.md) says.
2. **Run reviewers as in-process subagents** that did not write the work, never as new cloud sessions.
3. **Follow each repo's push rule.** A worker lands accepted commits as `task` says.
4. **Keep a ledger** at `$AGENT_LEDGER`, or else `agent-skills/ledger.md` under `$XDG_STATE_HOME`, or under `~/.local/state` when that is unset or not absolute, creating its directory. It holds open work per repo, owner decisions, questions waiting on the owner, running agents, the path to the [experiment record](references/experiments.md) beside it, and any plan that spans sessions or agents. The session running the agents rewrites it at every report it gives; a session that only reports leaves it unchanged and says which ledger lines git contradicts. Where the file sits in a git checkout, commit and push the ledger and its experiment record alone, under that repo's rules.
5. **Keep every plan in the ledger or a repo**, never only in a message or a temp path another machine cannot reach.
6. **Check in on an agent that has gone quiet** for longer than its step needs: read its latest output, then steer it, restart it, or report it, and update the ledger.
7. **Take every choice you have a clear recommendation for**, design tradeoffs included, such as push timing or slicing, and name each in the report. When unsure, get a `powerful`-tier read through `second-opinion` first. Ask the owner only about product tradeoffs and what you cannot answer.

## Resume

After compaction or in a fresh session, read the ledger first, then gather [the report's sources](references/report.md#sources).

## Report

Report in [its shape](references/report.md), with the owner's questions batched from every worker.

## See also

- `task` — the route each delegated task runs
- `design-review` — what the reviewers judge
- `second-opinion` — the read to get before asking the owner
- `workflow-review` — checks each due experiment and proposes its outcome

## Red flags

- A task worked in the coordinator's own context instead of delegated
- A reviewer started as a new cloud session
- A worker's commit stacked on one not yet accepted
- A plan held only in a message or a temp path
- A report from the session running the agents that leaves the ledger stale
- An owner question about a choice the coordinator could recommend, or one asked before a second opinion
- A quiet agent left unchecked
- A report built from memory rather than the ledger and git
- Owner questions placed below status
- Work called pushed without checking the remote
- A workflow change applied without an `open` line in the experiment record, or an experiment left open past its check date
