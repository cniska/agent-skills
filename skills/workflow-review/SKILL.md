---
name: workflow-review
description: Review how the work actually went — the owner's corrections, questions they had to ask, and friction sessions reported — and propose the changes to skills, agents and repo rules that the evidence repeats. Use after a stretch of work, or when asked what should change in the workflow.
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
4. **Read the current version** of the skill, agent or rules file involved. A finding the current version already settles is dropped.

## Judge

Sort each finding into one kind:

| Kind | What happened | Proposal |
|---|---|---|
| Conflict | The agent followed a skill and the owner corrected it | Change the skill; the owner decides which position stands |
| Unstated rule | The owner enforces it and nothing states it | Add it to the skill that owns that step, or make it a check |
| Repo rule | It holds in one project only | That repo's rules file |
| Dead weight | A step routinely finds nothing, or repeats another | Cut it, or scale it to the work |
| One-off | One session | None; list it |

A finding that fits two kinds goes in the one that changes less.

## Report

One heading per kind, one proposal per finding:

- **Where:** the skill, agent or rules file, and the line.
- **Evidence:** the quotes, each with its citation.
- **Change:** the smallest edit that would have prevented it, cuts first.
- **Check:** the eval case or test that would catch it coming back, where a grader can judge it from a trace.

A conflict's proposal also names the decision the owner has to make. Then the one-offs, one line each, and what was searched for and not found. No summary paragraph.

## See also

- `search-sessions` — finds the evidence
- `skill-writing` — makes an accepted change to a skill or agent, dry run included
- `agents-md` — makes an accepted change to a repo's rules
- `design-review` — the same judgment, applied to code
- `principles` — rules as checks, no drift

## Red flags

- A proposal resting on one session
- Paraphrasing what the owner said instead of quoting it
- Proposing a rule the current version already states
- Siding with a skill over the owner's correction instead of naming the conflict
- Growing a skill where a cut or a check would do
- Applying a conflict without the owner's call
