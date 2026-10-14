---
name: coordinate
description: Run work across several agents or repos for an owner — delegate each task, keep a ledger, batch the owner's questions and keep every agent moving. Use when you run or resume work across several agents or repos for an owner.
argument-hint: "<the work>"
---

# Coordinate

Hold work that spans agents or repos so none of it is lost, stranded, or left waiting on the owner without need. Each task itself runs through `task`.

## Rules

1. **Delegate each task to a subagent that loads the `task` skill with the Skill tool**, briefed with the repo, the task, every decision the owner settled, and where its plan lives. Read [the brief](references/brief.md) before writing one.
2. **Run reviewers as in-process subagents** that did not write the work, never as new cloud sessions.
3. **Follow each repo's push rule.** A worker pushes or lands each accepted commit before starting its next, as `task` says, so a return strands nothing stacked on it.
4. **Keep a ledger** at `$AGENT_LEDGER`, or else `agent-skills/ledger.md` under `$XDG_STATE_HOME`, or under `~/.local/state` when that is unset or not absolute, creating its directory. It holds open work per repo, owner decisions, questions waiting on the owner, running agents, and any plan that spans sessions or agents. Rewrite it at every report; where the file sits in a git checkout, commit and push that file alone, under that repo's rules.
5. **Keep every plan in the ledger or a repo**, never only in a message or a temp path another machine cannot reach.
6. **Check in on an agent that has gone quiet** for longer than its step needs: read its latest output, then steer it, restart it, or report it, and update the ledger.
7. **Take a choice a repo's rules or a conventional default decide**, such as push timing, slicing or which reviewer finding to take, and name it in the report. Ask the owner only about product or design tradeoffs.

## Resume

After compaction or in a fresh session, read the ledger first, then each open repo's `git log`, then check every agent the ledger lists as running.

## Report

- Outcome per repo first, then the owner's questions, batched from every worker; the rest in short bullets.
- Name every choice you made that the owner did not ask for.

## See also

- `task` — the route each delegated task runs
- `design-review` — what the reviewers judge

## Red flags

- A task worked in the coordinator's own context instead of delegated
- A reviewer started as a new cloud session
- A worker's commit stacked on one still awaiting review
- A plan held only in a message or a temp path
- A report that leaves the ledger stale
- An owner question about a choice a repo's rules or a default settle
- A quiet agent left unchecked
