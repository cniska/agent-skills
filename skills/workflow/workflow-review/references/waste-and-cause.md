# Waste and cause

What a finding cost, and why it happened.

## Waste

Each finding costs one of these:

| Waste | Example |
|---|---|
| Waiting | The owner answers a question a repo rule already settles; a worker idles on a reviewer |
| Rework | A return, a revert, a commit redone |
| Stranded work | An accepted commit not landed when the repo's rule would land it |
| Needless step | A step that runs on every change and finds nothing; an eval case or check that cannot fail |
| Lost context | Files read again after compaction because the plan lived only in a message |
| Escaped defect | A bug found after landing that a review or check should have caught |
| False stop | A gate refusing correct work |

Judge each finding's cost by the owner's time and the rework it caused, whatever its kind.

## Cause

Ask why the waste happened, then why that happened, until the answer is something a change can reach: a skill line, a repo rule, a check that is missing or matches wrongly, or a tool no one has built. Stop there. A cause such as "the agent forgot" is the symptom, not the cause, and a proposal resting on it changes nothing.

## False stops

A gate that refuses correct work is a defect of the gate, not of the work. The fix goes to the gate, narrowing what it matches or letting it see what it missed, never to a skill line that teaches the agent to work around it.

## Missing tools

The whys can end at no tool doing this: friction that repeats and that no skill line, repo rule or check can remove, because it needs a mechanism outside the repo, such as a command, a query or a small service; a hook or check inside the repo stays a check. The shape to propose is a small standalone tool in its own repo that gives agents a mechanism a skill line cannot, such as a record of past sessions, a gate on commits or an isolated checkout.

- Check first that no existing tool or option already does it, the repo's own and the upstreams' included.
- Name the friction it repeats, from the evidence, and the smallest tool that would remove it.
- A new tool is a product call: propose it to the owner as a Conflict, never build it. With too little evidence for a proposal, list it with the one-offs as an idea for the caller's backlog.
