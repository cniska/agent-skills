---
name: workflow-review
description: Review how the work actually went — the owner's corrections, questions they had to ask, and friction sessions reported — and propose the changes to skills, agents and repo rules that the evidence repeats, and whether each past change should stay or go by its signal. Use after a stretch of work, or when asked what should change in the workflow.
---

# Workflow review

Find where the workflow failed the owner, and say what should change so it does not happen again. The evidence is how the work actually went, read from past sessions, never what a skill says should have happened.

## The rules

- **Evidence is quoted, never paraphrased.** Each piece is cited by session, time and project.
- **A pattern needs two independent sessions.** One sighting is usually that session's judgment call: list it and propose nothing.
- **The owner's correction is the evidence.** When the agent followed a skill and the owner corrected it, the skill is in question, not the owner.
- **Cut before adding.** A step that routinely finds nothing, or a rule models now follow unprompted, is a proposal to remove it.
- **A mechanical rule becomes a check**, as rules as checks in `principles` says, not another sentence.

## Read

1. **Scope** to the window or projects the brief names; without one, ask for it.
2. **Find the evidence** through `search-sessions`:
   - the owner correcting an agent;
   - a question the owner had to ask mid-task that a skill should have answered;
   - friction a session reported about the workflow itself;
   - an eval case that regressed, where the repo has evals.
3. **Read each hit's thread**: what the agent did, what it was following (a skill line, a repo rule, nothing), and what the owner wanted instead.
   Ask why until the cause is one a change can reach, as [references/waste-and-cause.md](references/waste-and-cause.md) says.
4. **Read the current version** of the skill, agent or rules file involved. A finding the current version already settles is dropped.
5. **Read the upstreams** when the brief names an upstream list, as [references/upstreams.md](references/upstreams.md) says.
6. **Check each open experiment** in the record the brief names whose check date has passed: its signal before and after, as [references/experiments.md](references/experiments.md) says.

## Judge

Tag each finding with the waste it cost, as [references/waste-and-cause.md](references/waste-and-cause.md) says, and sort it into one kind:

| Kind | What happened | Proposal |
|---|---|---|
| Conflict | The agent followed a skill and the owner corrected it | Change the skill; the owner decides which position stands |
| Unstated rule | The owner enforces it and nothing states it | Add it to the skill that owns that step, or make it a check |
| Repo rule | It holds in one project only | That repo's rules file, under the Conflict heading so the owner decides |
| Dead weight | A step routinely finds nothing, or repeats another | Cut it, or scale it to the work |
| False stop | A gate refused correct work | Fix the gate, not the work |
| One-off | One session | None; list it |

A finding that fits two kinds goes in the one that changes less.

A proposal that touches permissions, how much autonomy the agents have, or a decision the owner settled goes under Conflict instead of its own kind.

## Report

One heading per kind, one proposal per finding, within each kind the costliest first:

- **Where:** the skill, agent or rules file, and the line.
- **Evidence:** the quotes, each with its citation.
- **Waste and cause:** what it cost, and the reachable cause the whys stopped at.
- **Change:** the smallest edit that would have prevented it, cuts first.
- **Check:** the eval case or test that would catch it coming back, where a grader can judge it from a trace.

A conflict's proposal also names the decision the owner has to make. Then the experiments checked, then the one-offs, one line each, and what was searched for and not found. No summary paragraph.

## See also

- `search-sessions` — finds the evidence
- `skill-writing` — makes an accepted change to a skill or agent, dry run included
- `agents-md` — makes an accepted change to a repo's rules
- `design-review` — the same judgment, applied to code
- `principles` — rules as checks, no drift

## Red flags

- A proposal resting on one session
- A proposal whose cause is the symptom, such as "the agent forgot"
- Paraphrasing what the owner said instead of quoting it
- Proposing a rule the current version already states
- Siding with a skill over the owner's correction instead of naming the conflict
- Growing a skill where a cut or a check would do
- Applying a conflict without the owner's call
- Proposing an upstream change because it looks good, with no friction or ledger gap behind it
- Keeping an experiment past its check date without comparing its signal before and after
