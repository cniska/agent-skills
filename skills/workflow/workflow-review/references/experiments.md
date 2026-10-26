# Experiments

A workflow change stays only if the signal it named moved the way it said.

## The record

The experiment record the routine or the owner names is a JSON-lines file, one line per event. An `open` line gives the commit that made or records the change (`sha`), the `signal` and its `direction`, when the change took effect (`from`), the `check` date, where another change overlaps it on that signal its `read`, and, when the owner approved an eval run, its `eval`: the case and the champion's and challenger's scores. A `close` line with the same `sha` ends the experiment; an `open` line without one is still open, and the latest `open` line for a `sha` counts.

## Thresholds

Before comparing, apply these to the tasks Check step 2 counts on each side, so noise is not read as a result:

- **Fewer than 10 on a side:** not enough data.
- **10 to 29:** report the direction, and judge only if owner interrupts agree with the signal: no worse when it moved as named, no better when it did not; or, where owner interrupts is the signal, only if time to land does not get worse. Otherwise it is not enough data, until the Verdict's bound on later check dates is reached.
- **30 or more:** judge on the signal the experiment named.

## Check

For each open experiment whose check date has passed:

1. **Confirm the new version ran** in the after window, since an installed copy can lag the repo: the version the session record shows for those sessions, or the changed skill among their loads. Where it did not run in all of the after window, the verdict is not installed yet; stop. Where the record cannot show which version ran, say so and go on.
2. **Pick and count the tasks** on each side: for a skill change, only the tasks that loaded that skill, on the same route on both sides. Never pool tasks across a change to a route, a hook or the model. Apply the Thresholds to the count.
3. **Compare the signal before and after** the change took effect, over windows of the same length, from the session record where it counts signals, or else by counting the events in the sessions. Compare rates per task, not raw counts: the two windows hold different amounts of work. Where the open line has a `read`, count the signal only as it says, such as one kind of event, or judge the commits it names as one change.
4. **Read a few of the counted events** on each side, so a number that moved for another reason, such as a quiet week or a change in what gets recorded, is not taken for the change working.
5. **Check the other signals** over the same windows. Owner interrupts and time to land outweigh review counts, which a change can improve by making reviews easier rather than the work better.

## Verdict

| Before and after | Proposal |
|---|---|
| The signal moved as named, and nothing weightier got worse | Keep |
| Flat, or the wrong way | Revert, or trim the part that did not pay off; prefer trimming to adding |
| The record shows the old version still running in part of the after window | Not installed yet: a new `from` at the time the new version first ran, and a check date after it |
| The record shows the new version has not run at all | Not installed yet: install it, with a new `from` at the install and a check date after it |
| Not enough data | A later check date, unless the `open` lines for that `sha` already carry more than one distinct `check` date for the same `from`; then 10 or more tasks a side are judged on direction alone, and fewer go to the owner as unproven, as a Conflict |

An after window the new version did not run in is never read as no effect.

The before and after are the evidence, so a verdict needs no second session.

## Report

An `Experiments` heading after the kinds, one entry per experiment checked: the commit and signal, the tasks on each side, the before and after with what each counts, the verdict, and for a revert, trim or install the change to make, and for not installed yet, what the record shows ran in the after window in place of the tasks and the before and after. Where the open line carries an `eval`, a revert or trim may also propose rerunning that case against its recorded scores, as its own Conflict naming the experiment. Each verdict is a proposal. An experiment whose check date has not passed is left out. The caller appends the `close` line, or for a later check date or a new `from` a new `open` line; the review changes nothing.
