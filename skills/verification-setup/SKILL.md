---
name: verification-setup
description: Create or reuse a way for agents to drive and inspect a running interface. Use when an agent cannot directly verify changed app behavior.
---

# Verification setup

Give the next agent an executable path to drive a changed interface and inspect what a user sees. Automated tests support that judgment but do not replace the agent's own run.

## Workflow

1. **Choose one interface.** Read the project rules, run commands, and testing docs. Name the user action and visible result that matter for the current change. Give web, mobile, and other surfaces separate recipes when their launch or controls differ.
2. **Audit the existing path.** Find how an agent launches the changed build in an isolated environment, checks readiness, operates the interface, inspects the visible result and any persistent side effect, captures evidence, and cleans up. Read existing scripts and tests behind the commands. A test suite alone does not complete this path.
3. **Fill only the gap.** Reuse a working agent-control recipe if one exists. Otherwise add the smallest working control harness needed and a project-local `<project>-verify-<surface>` skill in the project's established skill location. Give exact launch, readiness, interaction, observation, evidence, and cleanup instructions. Point to existing commands and tests instead of copying their procedures. Use the project's worktree or test-stack bootstrap and teardown when available; state which process, device, data, and credentials the run owns.
4. **Prove the recipe.** Follow the generated instructions from a clean start through cleanup. Operate one representative flow yourself, inspect the rendered result, and capture evidence of the action and result. Check a stored result when the behavior writes one. If controls are unreliable, improve the interface's semantic handles or add a suitable driver before calling the skill ready.
5. **Report the outcome.** Name the recipe used or files added, the behavior driven, the evidence captured, and any step that could not be run. An unexecuted recipe is a draft.

## See also

- `build` for verifying each slice
- `skill-test` for testing a changed skill across unlike projects

## Red flags

- Creating a skill that duplicates a working agent-control recipe
- Treating a passing browser or widget test as the agent's own interface check
- Placeholder commands, selectors, or assertions in a generated skill
- Coordinates used where a stable interface handle is needed
- Driving shared data or a device without checking who owns it
- Reporting an unrun recipe as verified
