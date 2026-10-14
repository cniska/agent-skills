# Evals

An eval case measures what a skill changes, so a change is kept or reverted on a score instead of a reading. A case is a prompt plus graders, run in a clean setup; every comparison runs the same cases twice, a champion against a challenger: the committed skill against an edit, one ref's skills against another's, or the skills against the set with this skill removed, which shows whether a case measures it. This covers cases run with Claude Code's `claude plugin eval`, whose case format is in the [eval docs](https://code.claude.com/docs/en/plugin-evals); under another harness, keep finding and scoring as they are and map the grader rules onto its own grader types. Where the repo keeps its cases, its commands and how to read a run are in the repo's eval docs.

## Find a behavior worth a case

A case measures something only where the model without the skill gets it wrong.

1. List the skill's rules a model would plausibly break unprompted — a house format, a default the skill overrides, a step it forbids.
2. Take the prompt from real use, in the user's own wording, never naming the skill. Where the user's real prompts name the fix itself ("rebase on main"), keep their register and drop the mechanism; phrasing that leans toward the wrong default ("pull main into my branch") is fair.
3. Run it once against the set with the skill removed and read what that side did. Keep the case only if it breaks the rule on a behavior check — failing the skill-fired check alone proves nothing, since a run without the skill always fails it. A case both sides pass sits at the ceiling and measures nothing. A case the skill's own side fails too is kept: it is a tuning target, the gap the next change to the skill should close. A suite that drives changes needs such cases; once the skill passes them all, add harder prompts or rules rather than relaxing graders. A triggering case — one that checks only that the skill loads for a request — is the exception: it cannot separate anything from no skill, and exists to compare versions of the skill's description.

## Trigger prompts

Where the repo has a trigger check, a written or changed description adds or updates that skill's positive and negative trigger prompts in the same change, as does a skill seen loading for the wrong request or not loading for its own. Take every prompt from a real request in the session record, never a guessed one: positives that loaded the skill or that the owner had to steer to it, negatives that went to a neighbouring skill. A skill with no real requests yet gets no trigger prompts.

## Write the case

- The prompt file: the prompt, a turn limit generous enough to finish, the tools it needs, and the skills it exercises as tags, so a run can select the cases of one skill. Frontmatter takes only the keys the eval format knows; an unknown one is an error. Listing a tool does not offer it; a run gets a gated tool only when the eval command grants it, so a "must not edit" grader can fail only when edits are granted.
- A scaffold when the task needs a workspace — a repo, files, an uncommitted change. Each run starts in an empty directory.
- Graders, one per rule, mechanical wherever the rule allows: a regex over the final message (the default target), the trace, or a file's contents; `tool_used`; `tool_order`. A model judge only for a short output with concrete PASS and FAIL conditions. Pair a check on the result with one on the steps.
- `file_exists` counts only files the run created, so a file that arrives by checkout or rebase, or that the scaffold made, is invisible to it; check a change to the workspace by grading the file's contents.
- Saved traces, real and hand-written, that show every grader both passing and failing, where the repo grades them offline, in the layout its eval docs set.
- Name nothing the run can see — directory, prompt, files — after evals or tests.
- Run a scaffold's check gate with the test runner itself (`node --test`, `pytest`), not through a package manager script that reaches a registry: the sandbox blocks the network, and the gate then fails for a reason the case is not about.
- A scaffold that contains examples — sibling skills, existing files in the house style — teaches both sides; such a case separates only on rules the examples do not show.
- A system binary the sandbox breaks on every run gets a one-line machine note in `append_system_prompt`, the same for both sides; the eval fixes each run's `PATH`, so the note is the only lever.

## Make each grader trustworthy

A grader that cannot fail, or fails on a good run, poisons every score after it: apply proven able to fail from `principles` to each one before trusting its score.

- Read the operation, not one spelling of it. The same commit arrives as `git commit -m "…"`, `-F - <<'EOF'`, a full binary path, a shell variable holding one, or a command on a later line of the same call (`\n` in the JSON, where `\b` does not anchor).
- Match a skill by its plugin-prefixed name (`<plugin>:<name>`): a tool's built-in skill can share the bare name, and the side without the skill would then pass a skill-fired check.
- Confine a trace regex to the tool calls it judges — for a shell command, the JSON text of its `command` field. The trace also holds the skill's own text, which names the very things the skill forbids.
- Prove each grader passes on a good trace and fails on a hand-written bad one, for every spelling: on saved traces before any paid run, where the repo can grade them offline; otherwise read a first run's trace against each grader by hand. A `tool_used` `input_match` runs against the call's input as JSON.
- The sandbox takes some mechanisms away: git hooks do not run, and a system binary may fail to write its cache — on macOS `/usr/bin/git`, and with it git's own subprocesses. Grade from the trace rather than working around it in the scaffold, expect a result check to fail for environment reasons, and let the check on the steps carry the verdict. A failure can be the run never seeing its input because a tool failed; check that it saw the input before counting the failure.

## Calibrate and score

Calibrate a new case against the set with the skill removed: five or more runs per side, and read the real trace of every failure before guessing at a cause.

- A failure that is the agent's is signal; one that is the grader's is a grader defect — fix it and rerun.
- A case where the skill's side passes every run and the removed side fails every run is one the suite can rely on.
- To score a change: run its skill's cases with the committed skill as the champion and your edit as the challenger, at the same run count. Keep it when the challenger holds or beats the champion past the run-to-run spread; revert it when it drops. A cut that holds the score is a win, since a shorter skill costs less context.
- Pin the model and the judge model, and record the Claude Code version whenever a score is reported or compared with an earlier run: the default model and the CLI change on their own. A champion and challenger run together share both; a score from another day does not.

## Red flags

- Keeping a change because it scored well once, or on a case both sides already pass
- Trusting a grader nobody has seen fail
- A trigger prompt written rather than taken from a real request, or a description changed with its trigger prompts left stale
