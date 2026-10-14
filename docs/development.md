# Development

## Setup

Tasks run through [mise](https://mise.jdx.dev), which also pins `shellcheck`, `jq` for the hook tests, and [Bun](https://bun.sh) for the TypeScript tooling.

```
mise install
mise run bootstrap
```

- `mise run bootstrap` installs dependencies and runs validation.
- Installing runs the `prepare` script, which points Git at [`.githooks/`](../.githooks/): the [agent-gates](https://github.com/cniska/agent-gates) `commit-subject`, `format` and `no-comments` gates.
- `mise tasks` lists every command.

To work on the skills in Claude Code, add this checkout as the marketplace and update the plugin after each commit:

```
claude plugin marketplace add <path>
claude plugin update cniska-skills@cniska
```

For other agents, `mise run link` symlinks every skill from this checkout into `~/.agents/skills` (or `SKILLS_DIR`), so an edit here is live in every agent.

- It removes links to skills that no longer exist.
- It leaves any other file or folder of the same name alone and reports it.
- `mise run link <skill>…` links only the skills you name.

## Checks

- `mise run validate` runs [`scripts/validate.ts`](../scripts/validate.ts).
- `mise run test` runs the bash and TypeScript tests.
- `mise run lint` runs Biome, `tsc`, knip (unused files, exports and dependencies) and the pinned `shellcheck`.
- `mise run test:evals` and `mise run test:triggers` are the eval checks that need no model, which [`evals/README.md`](../evals/README.md) describes.
- [`ci.yml`](../.github/workflows/ci.yml) runs `validate`, `lint`, `test`, `test:evals` and `test:triggers` on pull requests and pushes to `main`.
- The `commit-msg` hook refuses a commit subject that breaks the rule.
- [`commits.yml`](../.github/workflows/commits.yml) judges every pushed commit's subject.
- The `pre-commit` hook runs the repo's `format` script, stages what it changes in files the commit stages whole, and refuses a partly staged file it would change.
- [`format.yml`](../.github/workflows/format.yml) refuses unformatted files in CI.
- The `pre-commit` hook refuses comments in a TypeScript or shell file a commit changes, other than one a tool reads and acts on, such as a shebang.
- [`no-comments.yml`](../.github/workflows/no-comments.yml) refuses the same comments in CI.

## Layout

- [Conventions](conventions.md) says how a skill directory under `skills/` is written.
- `.claude-plugin/` holds the plugin and marketplace manifests for the [plugin](plugin.md).
- `evals/scenarios/` holds the eval cases, `evals/triggers/` the trigger prompts, and `evals/lib/` the eval tooling; `lib/` is the code it shares with the repo scripts in `scripts/`.
- `docs/` holds these pages, and no skill reads from it, since `npx skills add` copies only skill directories.
- A new worktree runs [`scripts/worktree-setup.sh`](../scripts/worktree-setup.sh) under [agent-worktree](https://github.com/cniska/agent-worktree) to trust and install the mise tools and install dependencies, and it needs no teardown.
- In Claude Code cloud sessions the proxy blocks mise.run and GitHub release downloads, so [`.claude/hooks/session-start.sh`](../.claude/hooks/session-start.sh) installs mise from npm and shellcheck from PyPI, and turns off mise's own shellcheck.
- That cloud hook also installs dependencies, and installs the `cniska-skills` plugin that [`.claude/settings.json`](../.claude/settings.json) enables, since a cloud session does not install it from the settings alone.

## Rules

[`AGENTS.md`](../AGENTS.md) holds the rules for authoring skills, code and commits in this repo.
