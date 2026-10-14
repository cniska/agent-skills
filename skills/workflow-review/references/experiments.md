# Experiments

A workflow change stays only if the signal it named moved the way it said.

## The record

The experiment record the brief names is a JSON-lines file, one line per event. An `open` line gives the change's commit (`sha`), the `signal` and its `direction`, when the change took effect (`from`), the `check` date, and, when the owner approved an eval run, its `eval`: the case and the champion's and challenger's scores. A `close` line with the same `sha` ends the experiment; an `open` line without one is still open, and the latest `open` line for a `sha` counts.

## Check

For each open experiment whose check date has passed:

1. **Compare the signal before and after** the change took effect, over windows of the same length, from the session record where it counts signals, or else by counting the events in the sessions. Compare rates per task, not raw counts: the two windows hold different amounts of work.
2. **Read a few of the counted events** on each side, so a number that moved for another reason, such as a quiet week or a change in what gets recorded, is not taken for the change working.
3. **Check the other signals** over the same windows. Owner interrupts and time to land outweigh review counts, which a change can improve by making reviews easier rather than the work better.

## Verdict

| Before and after | Proposal |
|---|---|
| The signal moved as named, and nothing weightier got worse | Keep |
| Flat, or the wrong way | Revert, or trim the part that did not pay off; prefer trimming to adding |
| Too little work since the change to tell | A later check date, unless the `open` lines for that `sha` already carry more than one distinct `check` date; then judge on what there is |

The before and after are the evidence, so a verdict needs no second session.

## Report

An `Experiments` heading after the kinds, one entry per experiment checked: the commit and signal, the before and after with what each counts, the verdict, and for a revert or trim the change to make. Where the open line carries an `eval`, a revert or trim may also propose rerunning that case against its recorded scores, as its own Conflict naming the experiment. Each verdict is a proposal. An experiment whose check date has not passed is left out. The caller appends the `close` line; the review changes nothing.
