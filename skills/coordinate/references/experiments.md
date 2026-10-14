# Experiments

A workflow change stays only if it moves what it was meant to move. Every change the coordinator applies to skills, agents, hooks or checks, proposed by a workflow review or not, is an experiment until it is checked.

## The record

`experiments.jsonl`, in the ledger's directory, is the one place experiments are recorded. Append one JSON line per event and never rewrite a line. The ledger names no experiment itself; it points at this file.

| Field | Value |
|---|---|
| `v` | `1` |
| `ts` | when the line was written, as an ISO time |
| `event` | `open` or `close` |
| `sha` | the commit that made the change, or, for a change outside any repo, the commit that records it: its own commit, in the repo whose skills, agents, hooks or checks the change belongs with, recording only that change |
| `signal` | the one signal it should move, as the session record names it, such as owner interrupts or time to land |
| `direction` | `up` or `down` |
| `from` | when the change reached the sessions doing the work, as an ISO time: the commit time, or later if it waits on an install; for a change outside any repo, the time it took effect |
| `check` | a date by which enough work has run for the signal to show, typically one to two weeks out |
| `outcome` | on `close` only: `keep`, `revert` or `trim` |
| `by_sha` | on a `revert` or `trim` close: the commit that made it, or records it, as for `sha` |
| `eval` | optional, when the owner approved an eval run for the change: `{case, champion, challenger}`, the case and each side's score |

An experiment is open while its `open` line has no `close` line with the same `sha`. To move a check date or `from`, append another `open` line for that `sha`, repeating its other fields; the latest one counts.

## Open

When the change lands, append an `open` line. Scores from an eval the owner approves later go on a new `open` line with the same `check`.

A second change aimed at the same signal while one is open muddies both checks: wait for the first check, or let the two checks overlap knowingly and say so in the report.

## Check

Brief each `workflow-review` run with the record's path. For each open experiment past its check date it proposes keep, revert, trim or a later check date, or, when the change was not installed yet, a new `from`: the time the new version first ran, or, when it never ran, an install, with the `from` at that install.

## Close

A later check date or a new `from` is a new `open` line, as The record says, never a close. Apply a keep, revert or trim verdict, then append a `close` line with its outcome, repeating the open line's other fields. A revert or trim lands as its own commit, or is recorded in one, named in `by_sha`. A trim is a new change, so it also opens its own experiment; a revert does not.
