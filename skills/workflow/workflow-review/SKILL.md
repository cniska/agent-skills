---
name: workflow-review
description: Review how the work actually went over weeks — the owner's corrections, questions they had to ask, and friction sessions reported — and judge each skill, agent and repo rule involved as a whole, proposing the cuts and rewrites the evidence shows, for the owner to decide. Use on a schedule over a long window of work, or when asked what should change in the workflow.
---

# Workflow review

Find where the workflow keeps failing the owner, and propose what should change so it stops. A single slip tells you little. A pattern across weeks of work tells you a skill is wrong. The usual fix is a shorter skill, not a longer one.

## Rules

- **Look at a long window**: at least four weeks, or since the skill last changed shape, whichever is longer. One day shows incidents, not patterns.
- **A pattern needs several independent sessions.** List a one-off and propose nothing for it.
- **The owner's correction is the evidence.** When an agent followed a skill and the owner corrected it, the skill is wrong. Restate the evidence in plain words, never quoting the owner, and cite it by session and time.
- **Judge the whole skill, not the line.** Read it end to end. Does it state its purpose, can an agent follow it in one read, and did it grow by patches? Its git log shows this, as many small additions after slips. A skill that grew this way gets a rewrite from its purpose, never another clause.
- **Cut before adding.** Propose a new rule only when the evidence shows a capable agent gets it wrong without one, and make a mechanical rule a check instead of a sentence.
- **Every proposal goes to the owner.** Change nothing yourself.

## Steps

1. Find the evidence in the window through `search-sessions`: the owner correcting an agent, a question the owner had to ask, a gate that refused correct work, a review that kept returning, and friction a session reported.
2. Group it by the skill, agent or repo rule each piece traces to, and trace each group to its cause, as [references/waste-and-cause.md](references/waste-and-cause.md) says.
3. For each skill with a pattern, read the current version whole and its history over the window, then judge it whole.
4. Report.

## Report

Lead with the skills that need a rewrite or a cut. For each one, give:
- its purpose in one line
- the pattern, with its citations
- why the current version causes it
- the change: a rewrite from its purpose, a cut, or, rarely, a rule or check

Then list the one-offs one line each, and what you searched for and did not find.

## See also

- `search-sessions`: finds the evidence
- `skill-writing`: makes an accepted change to a skill or agent
- `agents-md`: makes an accepted change to a repo's rules
