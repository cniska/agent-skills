# Skills

Self-contained engineering skills for AI coding agents — one per directory at `skills/<kind>/<name>/`, with `SKILL.md`, any `references/` it loads on demand, and any `scripts/` its text names, which an agent reaches by a path under the skill's own directory. The repo root is also the `cniska-skills` Claude Code plugin: `.claude-plugin/`, `hooks/` and `agents/` beside `skills/`, with `plugin.json` listing both kind folders; an agent preloads skills by their `cniska-skills:` name, and its test fails when a named skill is missing. `README.md` lists the full set and links the rest of the reference in `docs/`; `docs/conventions.md` holds the capability tiers and principles.

## Authoring a skill

- A skill is one of two kinds. `skills/workflow/` holds steps that produce an output; an unused one is fixed or dropped. `skills/expertise/` holds rules for what good looks like in one kind of work; it may go unused for a while.
- Frontmatter `name` matches the directory; `description` starts with an imperative verb and states when to use the skill.
- No project specifics, as the `skill-writing` skill says: commands, paths, branches and names stay in each repo's own rules, this repo's included.
- Self-contained: depend on nothing outside the skill's own directory, and reference other skills by bare name in `## See also`, never by path — `npx skills add` copies only that directory.
- End with a `## Red flags` section (never `## Anti-patterns`); keep the body terse and imperative.
- Name capability tiers (`fast` / `balanced` / `powerful`), never specific models.
- The validator enforces the mechanical rules — the two kind folders, an expertise skill naming a workflow skill only under `## See also`, every `## See also` name a skill in this repo, frontmatter, `## Red flags`, every link resolving inside the skill's own directory or to a web page on the validator's allowlist of tool links an agent follows to use a tool, no backticked path into another skill's directory, and no run of ten words shared by two files under `skills/`, `docs/`, `agents/`, `README.md` and `AGENTS.md`.
- Clean, lean, project-agnostic: fix failures two independent sessions show by editing their cause first.

## Code

- The plugin's `hooks/` run in other people's sessions, in whatever project is open, so they stay bash that needs only `jq` beyond git and the base system, never Bun or Node; repo scripts that parse or check are TypeScript on Bun, and scripts that orchestrate other tools stay shell.
- No comments in new or changed code; the agent-gates no-comments hook and workflow check every file a commit changes.

## Workflow

- New or changed skill: the `skill-writing` skill.
- Validate: `mise run validate`. Test: `mise run test`. Lint: `mise run lint`.
- Eval checks without a model, run in CI: `mise run test:evals` and `mise run test:triggers`. Model runs are local only; `evals/README.md` has them.

## Commits

- Work on a topic branch in its own worktree, never on `main`; no pull request in this repo.
- Commit each slice once validate, test and lint pass and a fresh reviewer accepts it, and push the branch after each commit.
- Land by rebasing on `origin/main` and fast-forwarding `main` to the branch once `review` accepts the whole branch, then push `main`; that accept is the owner's standing sign-off, so no landing waits on them.
- After `main` is pushed, a worker names `mise run plugin:update` as due in its hand-back and never runs it; the coordinator runs it once no coordinator's in-flight list, as `coordinate` keeps it, holds a running worker, then asks the owner to restart.
- A running session keeps the agent definitions and hooks it started with; each skill it loads, by the Skill tool or a subagent's preload, reads the plugin's source as it stands then.
- Conventional Commits `type(scope): description`; single-line subject, no body, ASCII, under 50 characters.
