# Dry run

Reading a changed skill shows how it reads; running it on real projects shows what it does. Run the new version and a baseline through subagents on unlike repos, judge what each run did rather than what it says it did, and act only on findings that converge.

## Before the run

- **Pick 2–3 unlike repos**, unlike in the dimension the change touches: repos that release differently for a release rule, a docs-heavy and a docs-light one for a doc rule. Repos that share a stack and shape hide the gap only one shape reveals, such as a release with no command or a project with no spec.
- **Write 3–6 checks** of what the change should make a run do, each one visible in a run's output or tool log, such as "flags the missing migration" or "reads the release reference before tagging". The checks go to the judge, never to a runner.
- **Pick one task per repo** that a user of that repo would plausibly ask for and that reaches the changed rule. Both versions get the same task.
- **Pick the baseline**: the previous version of the skill on an update, no skill on a create.

## Run blind

A runner that knows its work is a trial reads the skill more closely and follows it more literally than real work would, so the run hides that it is one.

- Give each runner the task as the user would type it. Nothing it sees, in the prompt, directory, branch or file names, mentions a test, a trial, a comparison or a skill under review, and it does not learn that other runs exist.
- Do not name the skill to load. Install the version under test where the runner's agent discovers skills, inside a scratch worktree of the target repo, never in the shared skill directory other sessions read.
- Run both versions on each repo in parallel. Output stays uncommitted in the scratch worktree; a run never commits or pushes.
- A headless runner (`claude -p`) ends at its first question, and a background subagent it starts dies when `-p` exits. Resume a stopped run in its own session with the answer a user would give, and judge only finished runs.

## Judge

1. **Read each run's own transcript or tool log** for which files it opened: whether it loaded the skill, which references it read, and at which step. A run that never loaded the changed text tested nothing; record that as a finding against the description, not as a pass. Read only those runs' logs, never other sessions'.
2. **Have one judge score both versions of a repo in one pass** against the checks, with the outputs under neutral labels and no sign of which is new. Use a different model from the runners where the host offers one.
3. **Read every output yourself** and compare with the judge. Where the two disagree, suspect the checks first and sharpen them.
4. **Then ask each runner for a friction report**, as a follow-up to the same agent: the judgment calls it had to make, where the guidance was unclear or fought the repo, and what it did differently from what it expected. Asked after the work, the question cannot shape the run.

## Act

- The same failed check or the same friction from independent repos is a defect in the skill: fix it. Friction from a single run is usually that repo's judgment call: leave it.
- Fold the fixes in, then re-run the worst-affected repo when a fix changed behavior.
- Report the change, the checks, each repo's verdict for both versions, the fixes folded in, and whether the new version should ship.
- Remove the scratch worktrees, or hand an output to the user when it beats what the repo has.
