# Skills

Self-contained engineering skills for AI coding agents — one per directory at `skills/<kind>/<name>/`, with `SKILL.md` and any `references/` it loads on demand. The repo root is also the `cniska-skills` Claude Code plugin: `.claude-plugin/`, `hooks/` and `agents/` beside `skills/`, with `plugin.json` listing both kind folders; an agent preloads skills by their `cniska-skills:` name, and its test fails when a named skill is missing. `README.md` lists the full set and links the rest of the reference in `docs/`; `docs/conventions.md` holds the capability tiers and principles.

## Authoring a skill

- A skill is one of two kinds. `skills/workflow/` holds steps that produce an output; an unused one is fixed or dropped. `skills/expertise/` holds rules for what good looks like in one kind of work; it may go unused for a while.
- Frontmatter `name` matches the directory; `description` starts with an imperative verb and states when to use the skill.
- No project specifics: a skill states what holds in any repo and defers commands, paths, branches and names to the repo's own rules, this repo included.
- Self-contained: depend on nothing outside the skill's own directory, and reference other skills by bare name in `## See also`, never by path — `npx skills add` copies only that directory.
- End with a `## Red flags` section (never `## Anti-patterns`); keep the body terse and imperative.
- Name capability tiers (`fast` / `balanced` / `powerful`), never specific models.
- The validator enforces the mechanical rules — the two kind folders, an expertise skill naming a workflow skill only under `## See also`, every `## See also` name a skill in this repo, frontmatter, `## Red flags`, every link resolving inside the skill's own directory.
- Add guidance only for friction that repeats in real use; prefer trimming to growing.
- After a material change to a skill, dry-run it on unlike real repos (the `skill-writing` skill) before pushing.

## Code

- The plugin's `hooks/` run in other people's sessions, in whatever project is open, so they stay bash that needs only `jq` beyond git and the base system, never Bun or Node; repo scripts that parse or check are TypeScript on Bun, and scripts that orchestrate other tools stay shell.
- No comments in new or changed code; the agent-gates no-comments hook and workflow check every file a commit changes.

## Workflow

- New or changed skill: the `skill-writing` skill.
- Validate: `mise run validate`. Test: `mise run test`. Lint: `mise run lint`.
- Eval checks without a model, run in CI: `mise run test:evals` and `mise run test:triggers`. Model runs are local only; `evals/README.md` has them.

## Commits

- Commit directly to `main` — no branch or PR.
- Push each commit to `main` once validate, test and lint pass and a fresh reviewer accepts it; that accept is the owner's standing sign-off, so no push waits on them.
- Conventional Commits `type(scope): description`; single-line subject, no body, ASCII, under 50 characters.
