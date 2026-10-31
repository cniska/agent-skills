# Create

No `AGENTS.md` exists at the target. Write only rules the code already follows, inferred from evidence.

1. Gather evidence:
   - lint and format config, from which the style rules follow.
   - test layout and scripts, the manifest's tasks and the CI config.
   - framework and runtime, from manifests and lockfiles.
   - commit style from the recent log. The log is the authority, so copy the format in use, Conventional Commits or not. Where one format leads but is not universal, name it as house style and say nothing enforces it. Where the log has no format, say so.
   - any existing `CLAUDE.md` or `.cursorrules`: migrate the real rules and leave the tool-specific memory behind.
2. Draft sections from the menu below only where evidence supports a concrete rule, shaped to this project.
3. Follow every rule in the skill's What matters.
4. Wire up tool bridges. A tool that reads its own memory file rather than `AGENTS.md` gets a one-line pointer, for Claude Code a `CLAUDE.md` holding only `@AGENTS.md`. Write that one by default, and bridge another tool only where the repo shows it in use (`.cursorrules`, `.windsurfrules`, `copilot-instructions.md`). In a repo whose conventions are not yours to set, such as a public project with no agent tooling, skip the bridge and report why.
5. Report which sections you filled and the evidence behind each.

## Sections to consider

A menu of common sections, not a skeleton. Draw from it, rename, add what the project needs and leave out what it does not, since an empty section is noise. Put the load-bearing rules first.

- **Architecture**: module boundaries, entry points, what depends on what. The map is long and rarely needed whole, so keep a pointer to an architecture doc here, as placement by cost says.
- **Invariants**: the rules that must always hold, each checked by a test or a review.
- **Workflow**: how to build, run, verify and release, each a one-line command reference, or the trigger where a release has no single command, such as pushing a `vX.Y.Z` tag. Add the checks every commit runs and the channels a release publishes to. The executable it names owns the procedure and its gates, and development-process rules go under Process. In a file that already keeps commands and process under one heading of its own, leave that heading.
- **Process**: development and agent-behavior rules that are neither code contracts nor commands, such as branching, pull request or direct landing, worktrees, when to commit, and sign-off.
- **Commits**: message format and discipline. Defer to the `git` skill's Conventional Commits only where the log shows no format of its own.
- **Pull requests**: when to open one, the review gate, and title and body rules, where the project uses them.
- **Code**: language and structure rules particular to this repo.
- **Style**: formatting, naming, and the lint and format tools of record.
- **Docs**: where docs live and when they change.
- **Testing**: test layout, how to run the suite, what a test may mock at a boundary, and coverage expectations.
