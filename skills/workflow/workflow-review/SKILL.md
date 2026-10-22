---
name: workflow-review
description: Review how the work actually went — the owner's corrections, questions they had to ask, and friction sessions reported — and propose the changes to skills, agents and repo rules that the evidence repeats, and whether each past change should stay or go by its signal. Use when a task lands or stops, or when asked what should change in the workflow.
---

# Workflow review

Find where the workflow failed the owner, and say what should change so it does not happen again. The evidence is how the work actually went, read from past sessions, never what a skill says should have happened.

## The rules

- **Evidence is quoted, never paraphrased.** Each piece is cited by session, time and project.
- **A pattern needs two independent sessions.** One sighting is usually that session's judgment call: list it and propose nothing. An eval or check finding rests on the case and its result instead.
- **The owner's correction is the evidence.** When the agent followed a skill and the owner corrected it, the skill is in question, not the owner.
- **Cut before adding.** A step that routinely finds nothing, or a rule models now follow unprompted, is a proposal to remove it.
- **A mechanical rule becomes a check**, as rules as checks in `principles` says, not another sentence.
- **Propose changes only to what the user commits to:** the rules of their repos and the skills whose source sits in a checkout of theirs. Friction with a skill installed from elsewhere becomes a rule in the repo's `AGENTS.md`, where skills defer everything project-specific; never an edit to the installed copy, and nothing sent to its author.

## Read

1. **Scope** to the task the brief names, or to the window or projects the owner asks about; without either, ask. A task's sessions are the run that did it and the subagents that run started, which its agent tool calls name.
2. **Find the evidence** through `search-sessions`, in the scope:
   - the owner correcting an agent;
   - a question the owner had to ask mid-task that a skill should have answered;
   - friction a session reported about the workflow itself, or a gate stop, a review return or a retry;
   - an eval case that regressed, where the repo has evals.
   When the scope is one task, read its steps first where the session record traces them: a refused or failed step, a review return, a long step, an agent heavy on tokens or a compaction is where to open its transcripts; then search every earlier session for each piece of friction it shows; one with no earlier sighting is a one-off.
3. **Read each hit's thread**: what the agent did, what it was following (a skill line, a repo rule, nothing), and what the owner wanted instead.
   Ask why until the cause is one a change can reach, as [references/waste-and-cause.md](references/waste-and-cause.md) says.
4. **Read the current version** of the skill, agent or rules file involved. A finding the current version already settles is dropped.
5. **Check each open experiment** in the record the brief names whose check date has passed: its signal before and after, as [references/experiments.md](references/experiments.md) says. A check that needs the signals of a session record the host lacks is reported as skipped, never guessed.
6. **Check skill usage** where the session record counts skill loads by version, as agent-record's `skill-usage` signal does where installed: a skill a route names that does not load in that route's tasks, or that loads and changes nothing, its tasks doing no step it asks for more often than the route's tasks without it. Count and compare the tasks under the Thresholds and Check steps 2 to 4 of [references/experiments.md](references/experiments.md). Each is Dead weight. Where the record counts no loads, say so and skip this step.
7. **Check the repo's evals and checks**, as its rules name them, from their cases and the results already recorded, running none: a case that measures nothing, both sides passing or both failing; a trigger prompt that loads the wrong skill; a check the repo has that no route runs. Each is a finding.

## Judge

Tag each finding with the waste it cost, as [references/waste-and-cause.md](references/waste-and-cause.md) says, and sort it into one kind:

| Kind | What happened | Proposal |
|---|---|---|
| Conflict | The agent followed a skill and the owner corrected it, or the change crosses the owner's boundary | The change; the owner decides whether it stands |
| Unstated rule | The owner enforces it and nothing states it | Add it to the skill that owns that step, or make it a check |
| Dead weight | A step routinely finds nothing or repeats another, or a skill a route names does not load or changes nothing | Cut it, scale it to the work, or fix what keeps it from loading |
| False stop | A gate refused correct work | Fix the gate, not the work |
| One-off | One session | None; list it |

A finding that fits two kinds goes in the one that changes less, unless it crosses the owner's boundary, which makes it a Conflict.

The owner's boundary is a repo's rules file, permissions, how much autonomy the agents have, the decisions the owner settled, adding, running or changing an eval, and a new tool; a rule that holds in one project only crosses it, since it goes in that repo's rules file.

## Report

One heading per kind, one proposal per finding, within each kind the costliest first:

- **Where:** the skill, agent or rules file, and the line; for a missing tool, where the friction occurs.
- **Evidence:** the quotes, each with its citation, or for an eval or check finding, the case and the result that shows it.
- **Waste and cause:** what it cost, and the reachable cause the whys stopped at.
- **Change:** the smallest edit that would have prevented it, cuts first; for a missing tool, the smallest tool.
- **Check:** the cheapest test or check that would catch it coming back. Propose an eval only when the change's risk justifies one: a behavior the skill exists for, a past regression, or a change no cheaper check can judge, and say why. A proposed eval goes to the owner as its own Conflict, naming the change it judges; the change stays in its kind, and the signal on the check date judges it until the owner decides.

A conflict's proposal also names the decision the owner has to make. Then the experiments checked, then the one-offs, one line each, and what was searched for and not found. No summary paragraph.

## See also

- `search-sessions` — finds the evidence
- `skill-writing` — makes an accepted change to a skill or agent
- `agents-md` — makes an accepted change to a repo's rules
- `design-review` — the same judgment, applied to code
- `principles` — rules as checks, no drift

## Red flags

- A proposal resting on one session
- A proposal whose cause is the symptom, such as "the agent forgot"
- Paraphrasing what the owner said instead of quoting it
- Proposing a rule the current version already states
- Proposing an edit to an installed skill, or a change for its author, instead of a rule in the repo's `AGENTS.md`
- Siding with a skill over the owner's correction instead of naming the conflict
- Growing a skill where a cut or a check would do
- Applying a conflict without the owner's call
- Running an eval, or proposing one the change's risk does not justify
- A finding whose fix is a tool, written as a skill line
- A skill a route names judged by its text alone, where the record shows whether it loads
- Keeping an experiment past its check date without comparing its signal before and after
