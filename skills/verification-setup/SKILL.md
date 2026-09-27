---
name: verification-setup
description: Create or reuse a way for agents to drive and inspect a running interface. Use when an agent cannot directly verify changed app behavior.
---

# Verification setup

Give the next agent an executable path to drive a changed interface and inspect what a user sees. Automated tests support that judgment but do not replace the agent's own run.

## Workflow

1. **Choose one interface.** Read the project rules, run commands, and testing docs. Name the user action and visible result that matter for the current change. Give web, mobile, and other surfaces separate recipes when their launch or controls differ.
2. **Audit the existing path.** Find how an agent launches the changed build and its base build in an isolated environment, checks readiness, operates the interface, inspects the visible result, any persistent side effect, and the diagnostics an engineer checks on this surface (console and page errors, failed requests, server or daemon logs), captures evidence, and cleans up. Read existing scripts and tests behind the commands. A test suite alone does not complete this path.
3. **Fill only the gap.** Reuse a working agent-control recipe if one exists. Otherwise add the smallest working control harness needed and a project-local `<project>-verify-<surface>` skill in the project's established skill location. Give exact launch, readiness, interaction, observation, evidence, and cleanup instructions. Point to existing commands and tests instead of copying their procedures. Run the base build from a second checkout with its own data, driven by the current harness, since the harness may be newer than the base. Write evidence to a path the run does not delete and outside the checkout. Script launch, readiness, evidence capture, and cleanup so they fail loudly; keep the skill's prose for what to operate and how to judge the result. Use the project's worktree or test-stack bootstrap and teardown when available; derive ports, browser profiles, and app data per run so concurrent agents do not collide, and state which process, device, data, and credentials the run owns.
4. **Prove the recipe.** Follow the generated instructions from a clean start through cleanup. Operate one representative flow yourself, inspect the rendered result, and capture evidence of the action and result on both the base and changed build, saved where a reviewer can open it without rerunning. Run both builds at once to prove they do not collide, and make one check fail to prove the run exits non-zero. Check a stored result when the behavior writes one. If controls are unreliable, improve the interface's semantic handles or add a suitable driver before calling the skill ready.
5. **Report the outcome.** Name the recipe used or files added, the behavior driven, the evidence captured and where it is saved, and any step that could not be run. An unexecuted recipe is a draft.

## See also

- `build` for verifying each slice
- `skill-test` for testing a changed skill across unlike projects

## Red flags

- Creating a skill that duplicates a working agent-control recipe
- Treating a passing browser or widget test as the agent's own interface check
- Placeholder commands, selectors, or assertions in a generated skill
- Coordinates used where a stable interface handle is needed
- Driving shared data or a device without checking who owns it
- Fixed ports, profiles, or app data that break a second concurrent run
- Launch, readiness, or cleanup left as prose for the agent to improvise
- Reporting an unrun recipe as verified
