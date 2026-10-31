# Create

No `AGENTS.md` exists at the target. Infer the project's *real* conventions from evidence — never invent aspirational rules the code doesn't follow.

1. Gather evidence:
   - lint/format config (`.oxlintrc.json`, `.oxfmtrc.json`, `.eslintrc*`, `.prettierrc*`, `rustfmt.toml`, `ruff.toml`) — the style section writes itself from these.
   - test layout and scripts (`package.json` scripts, test dirs, CI config).
   - framework and runtime (manifest files, lockfiles).
   - commit style from `git log --oneline -30` — the log is the authority, so copy the format actually in use. A log that consistently isn't Conventional Commits is the repo's rule, not drift to correct. Where a format leads but isn't universal, name it as house style and say it isn't enforced; where the log is genuinely formatless, say that instead of dignifying the largest pile as a convention.
   - any existing `CLAUDE.md` or `.cursorrules` — migrate real rules, drop tool-specific memory.
2. Draft sections from the menu below **only where evidence supports a concrete rule**, shaping them to this project. Skip the rest.
3. Follow every convention in the skill — one rule per bullet, no hard wrap, terse.
4. Wire up tool bridges. A tool that reads its own memory file rather than `AGENTS.md` needs a one-line pointer — for Claude Code, a `CLAUDE.md` containing only `@AGENTS.md`. Write that one by default; bridge any *other* tool only where the repo shows it in use (`.cursorrules`, `.windsurfrules`, `copilot-instructions.md`). Skip it in a repo whose conventions aren't yours to set — a public project with no agent tooling anywhere, where a tool-specific file reads as noise in review; report that you skipped it and why.
5. Report which sections you filled and what evidence backed each.

## Sections to consider

A menu of common dimensions, not a required skeleton. Shape the actual sections from the project's evidence — draw from these, rename them, add what this project needs, and drop what it doesn't. Use only sections with something concrete to say; an empty section is noise. Order so the load-bearing rules come first. The useful taxonomy differs per project and shifts as tools change — that structure is your call, not a fixed recipe.

- **Architecture** — module boundaries, entry points, what depends on what. Usually long and rarely needed in full — the clearest case for the skill's rule on deciding placement by cost: keep a load-bearing pointer to a dedicated architecture doc here, not the map itself.
- **Invariants** — rules that must never break; the non-negotiables. Each one has a test or a review that checks it.
- **Workflow** — how to build, run, verify, and release locally, each as a one-line command reference (for a release with no single command, name the trigger instead — e.g. push a `vX.Y.Z` tag), the checks every commit runs, and the channels a release publishes to. The executable it names (a release script, a CI workflow) owns the procedure and any pre-release gates; keep this section to commands and put development-process rules under Process. That split is the default for a file you're shaping, not a mandate to impose on one you're updating — where a file already houses both under its own heading, leave it rather than churn through a rename.
- **Process** — development and agent-behavior rules that are neither code contracts nor commands: branching and PR-vs-direct policy, worktrees, when to commit, autonomous-execution and sign-off expectations. Distinct from Workflow (commands) and Invariants (code contracts).
- **Commits** — message format and discipline (defer to the `git` skill's Conventional Commits only where the log shows no established format of its own).
- **Pull requests** — when to open one, the review gate, title and body rules (omit if the project doesn't use PRs).
- **Code** — language and structure rules specific to this repo.
- **Style** — formatting, naming, lint/format tool of record.
- **Docs** — where docs live and when to update them.
- **Testing** — test layout, how to run them, what a test may mock at a boundary, coverage expectations.
