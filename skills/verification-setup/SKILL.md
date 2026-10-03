---
name: verification-setup
description: Create or update a project-local skill that lets agents drive and inspect a running interface. Use when an agent cannot directly verify changed app behavior, or when an existing verify skill may have drifted from the app.
argument-hint: "[surface-or-area]"
---

# Verification setup

Give the next agent an executable path to launch a changed build, drive a feature the way a user does, and inspect what a user sees. Its reader opens it cold, mid-task. Automated tests support that judgment but do not replace the agent's own run.

Two modes, detected by whether the project already has a verification skill — any project-local skill that launches, drives, and observes the app, hand-written ones included: **Create** (none exists) writes `<project>-verify-<surface>`; **Update** (one exists) edits that skill under its own name and proves its feature map against the current app. Never write a second skill beside an existing one. A shared skill installed from elsewhere is a harness the project skill calls, used as-is and never edited here. An existing skill that covers one narrow path becomes one feature file, and the skill grows the sections below around it.

## Placement

Put the skill where the repo keeps the skills agents load when working in it (`.claude/skills/`, `.agents/skills/`, or wherever the others symlink to), never a directory of skills the repo ships to others. With none, infer the team's tools from the agent config the repo carries; ask only when that leaves it open. In a monorepo, each area with a user surface gets its own skill, one area per run. Work on a topic branch in a worktree, commit locally, and leave pushing and the PR to the user.

## Create

1. **Interview the repo.** Answer from code; ask the user only what cannot be observed.
   - **Surface:** what a user touches and the action and visible result that matter. Pick the primary surface and list the rest; give surfaces separate recipes when their launch or controls differ.
   - **Run:** the repo's own run task, its ports, env vars, seed data, and auth. When sign-in needs a human, find a test or guest login in tracked config or fixtures and enable it in gitignored local config; with none, report it as the blocker. Values from a deployed environment stay out of the skill.
   - **Drive:** reuse an existing agent-control recipe or harness — browser specs, PTY helpers, simulator tooling, a debug port — before adding one. A test suite alone does not complete this path.
   - **Observe:** the visible result, persistent side effects, and the diagnostics an engineer checks on this surface (console and page errors, failed requests, server or daemon logs).
   - **Real machine:** whether a drive needs the developer's own home, credentials, or account. When it does, bracket every such drive: fingerprint that state by metadata before and after, and fail on any change. A path is read-only only once a bracketed run has shown it.
   - **Isolate:** walk the source for fixed ports, shared data directories, lock files, and global state. When two instances cannot run side by side, the skill says so and refuses to drive an instance it did not start.

   When `HEAD` does not build or start, stop and report it — a skill written against a broken base teaches wrong steps. When the base is sound but this host lacks something (credentials, a toolchain), write the skill, leave it uncommitted, and report blocked with the step that unblocks the proving run.
2. **Write the skill**, laid out like the repo's other skills, with a `description` naming the app, the surface, and when to reach for it. Fill every step from the interview — no placeholders:
   - **Launch:** the exact command, readiness check, and teardown. Derive ports, browser profiles, and app data per run so concurrent agents do not collide. Run the base build — the default branch, or `HEAD` when the only change is this skill — from a second checkout with its own data, dependencies, and generated files, driven by the current harness, since the harness may be newer than the base.
   - **Doctor:** one read-only check that the instance is worth driving — process up, the right build, the port owned by this run, auth valid — plus each helper's self-test. Every check can fail; one that compares a value with itself proves nothing. Run first and whenever anything looks off.
   - **Drive:** this repo's real selectors, commands, and routes. Prefer stable handles (accessibility labels, data attributes, prompt strings, routes) over coordinates and tab order.
   - **Evidence:** a per-run directory outside the checkout that cleanup never deletes, named in the skill. Mask anything that can carry a credential (logs, DOM dumps, request captures) before writing it. Drive the real user path, not internal setters or test-only endpoints; capture the action and the resulting state; check side effects alongside what is visible; mock only at a boundary production already isolates. Confirm by observation what a dry-run mode actually skips.
   - **Findings:** where a defect in the change, a defect outside it, and a problem only this machine causes each get written down.
   - **Cleanup:** stop what the run started by PID or recorded identifier, never by process name.
   - **Helpers:** script launch, readiness, evidence capture, and cleanup so they fail loudly; keep prose for what to operate and how to judge the result. Write helpers in the repo's own language on a harness it already has, show each invocation in the skill, and give them one self-test of their contract (masking, exit status, timeouts) seen failing against a broken copy.
3. **Seed the feature map**: `features/README.md` indexing one file per user-facing feature, starting from the top few found in routes, commands, menus, or docs. Each file has `Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>`, and `Gotchas`, and ends in the observable state that proves the feature works. A proof that drives one convenient entry point is incomplete when the map lists others.
4. **Prove it.** From a clean build, follow the skill through cleanup: Launch, Doctor, drive one mapped feature on both base and changed build, capture evidence, Cleanup. Run both builds at once to prove they do not collide, make one check fail to prove the run exits non-zero, and check a stored result when the behavior writes one. Confirm the evidence survives cleanup and no process or port is left. If controls are unreliable, improve the interface's semantic handles or add a driver. Run Cleanup after every failed attempt. Do not commit a skill that has not completed this run.

## Update

When the skill lacks a section from Create step 2 or has no feature map, add them per Create, keeping its content, then prove it. Otherwise:

1. **Index hygiene.** Fix missing, duplicate, or dead entries in the feature map index.
2. **Source pass.** For each feature file, spawn one read-only agent on a **balanced-tier** model to read the source it describes and return drift with citations — renamed routes, removed commands, new sub-features — and one live recipe. Readers never drive the app or edit files. Sweep recent changes for user-facing features the map lacks; require a concrete source path before calling one missing.
3. **Live pass**, required even when source looks clean. Drive every mapped feature in one session in a throwaway worktree, serially, following the skill's own Launch. Run Doctor before the first drive and after any failed one; a step that fails is a finding.
4. **Triage.** Wrong or missing description is drift: fix the map. Working behavior the harness cannot drive is a harness gap: fix it and re-drive it. Broken app behavior is a product defect: report it and leave product code alone. Edit only the verification skill's own directory and the harness it owns.
5. **Commit only proven corrections.** A defect in a feature the run could not drive stays as written and goes in the outcome, with the unmet prerequisite and the route attempted.

## Output

Name the mode, the skill and files added or changed, the behavior driven, the evidence captured and its path, and any step that could not be run. Update ends in one outcome: **clean** (every feature covered, nothing to change, no branch), **changed** (one branch of proven corrections, listing any feature it could not drive and why), or **blocked** (exactly what stopped coverage). An unexecuted recipe is a draft.

## See also

- `build` for verifying each slice
- `skill-test` for testing a changed skill across unlike projects

## Red flags

- Writing a second verification skill beside an existing one, or one that duplicates a working agent-control recipe
- Placing the skill in a directory of skills the repo ships to others
- Treating a passing browser or widget test as the agent's own interface check
- Placeholder commands, selectors, routes, or assertions in a generated skill
- Coordinates used where a stable interface handle is needed
- Fixed ports, profiles, or app data that break a second concurrent run
- Launch, readiness, or cleanup left as prose for the agent to improvise
- A Doctor check that cannot fail, or a helper with no self-test
- A helper in a language the repo does not use
- A drive against the real machine with no before-and-after state check
- Evidence holding an unmasked token, key, or cookie
- A Cleanup that kills by process name or deletes the evidence
- Papering over a product defect by editing the feature map
- Committing, or reporting as verified, a recipe that has not completed its own proving run
- Pushing the branch or opening the PR
