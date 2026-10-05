# Skills

Self-contained engineering skills for AI coding agents — one per directory at `skills/<name>/`, with `SKILL.md` and any `references/` it loads on demand. `README.md` is the reference for the full set, capability tiers, and principles.

## Authoring a skill

- Frontmatter `name` matches the directory; `description` starts with an imperative verb and states when to use the skill.
- Self-contained: depend on nothing outside the skill's own directory, and reference other skills by bare name in `## See also`, never by path — `npx skills add` copies only that directory.
- End with a `## Red flags` section (never `## Anti-patterns`); keep the body terse and imperative.
- Name capability tiers (`fast` / `balanced` / `powerful`), never specific models.
- The validator enforces the mechanical rules — frontmatter, `## Red flags`, every link resolving inside the skill's own directory.
- Add guidance only for friction that repeats in real use; prefer trimming to growing.
- After a material change to a skill, dry-run it on unlike real repos (the `skill-test` skill) before pushing.

## Workflow

- New skill: `mise run new-skill <kebab-case> "<imperative description>"` (or copy `SKILL_TEMPLATE.md`).
- Validate: `mise run validate`. Test: `mise run test`. Lint: `mise run lint`.

## Commits

- Commit directly to `main` — no branch or PR.
- Conventional Commits `type(scope): description`; single-line subject, no body, ASCII, under 50 characters.
