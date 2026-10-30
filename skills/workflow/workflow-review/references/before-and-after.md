# Before and after

A change stays only if the friction it aimed at fell once it landed, and a skill stays in a route only if its tasks differ from the route's tasks without it.

## Thresholds

Before comparing, apply these to the tasks Compare step 2 counts on each side, so noise is not read as a result:

- **Fewer than 10 on a side:** not enough data.
- **10 to 29:** report the direction, and judge only if owner interrupts agree with the friction compared: no worse when it fell, no better when it did not; or, where owner interrupts is the friction compared, only if time to land does not get worse. Otherwise it is not enough data, until the Verdict's bound is reached.
- **30 or more:** judge on the friction compared.

## Compare

Compare each proposal the owner accepted that the coordinator's ledger, as the routine or the owner names it, pairs with the commit that landed it: the review's date, the proposal's Where and Change, and the commit's sha. The friction it aimed at is that proposal's Evidence, in that date's report among the earlier reports the routine or the owner names. A commit with no pairing is never compared, so a drift or defect fix is never judged here.

1. **Confirm the new version ran** in the after window, since an installed copy can lag the repo: the version the session record shows for those sessions, or the changed skill among their loads. The after window starts when the new version first ran, or at the commit time where the record cannot show which version ran; say which.
2. **Pick and count the tasks** on each side: for a skill change, only the tasks that loaded that skill, on the same route on both sides. Never pool tasks across a change to a route, a hook or the model. Apply the Thresholds to the count.
3. **Compare the friction before and after** the change took effect, over windows of the same length: the owner's corrections, asks and session friction it aimed at, counted from the session record where it counts signals, or else by counting the events in the sessions. Compare rates per task, not raw counts: the two windows hold different amounts of work. Where two recent changes aim at the same friction, count only the events each one's proposal quoted, or judge them as one change and say so.
4. **Read a few of the counted events** on each side, so a number that moved for another reason, such as a quiet week or a change in what gets recorded, is not taken for the change working.
5. **Check the other signals** over the same windows. Owner interrupts and time to land outweigh review counts, which a change can improve by making reviews easier rather than the work better.

## Verdict

| Before and after | Proposal |
|---|---|
| The friction fell, and nothing weightier got worse | Keep |
| Flat, or the wrong way | Revert, or trim the part that did not pay off; prefer trimming to adding |
| The record shows the old version still running in part of the after window | Not installed yet: compare again from the time the new version first ran |
| The record shows the new version has not run at all | Not installed yet: install it |
| Not enough data | Compare again at the next review; at the first review once the change is 14 days old, 10 or more tasks a side are judged on direction alone, and fewer go to the owner as unproven, as a Conflict |

An after window the new version did not run in is never read as no effect.

The before and after are the evidence, so a verdict needs no second session.

## Report

A `Recent changes` heading after the kinds, one entry per change compared: its commit and the friction it aimed at, the tasks on each side, the before and after with what each counts, the verdict, and for a revert, trim or install the change to make, and for not installed yet, what the record shows ran in the after window in place of the tasks and the before and after. Each verdict is a proposal to the owner; the review changes nothing.
