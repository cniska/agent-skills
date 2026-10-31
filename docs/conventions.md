# Conventions

How a skill is written, which models it asks for, and where each principle lives.

## Skill conventions

Each skill is one self-contained directory: `skills/<kind>/<name>/SKILL.md`, where the kind is `workflow` or `expertise`, plus any `references/` files it loads only when a task needs them, and `scripts/` where the skill bundles an executable it names, reached by the path the skill loaded from. `SKILL.md` has YAML frontmatter (`name` matching the directory, `description` starting with an imperative verb) and a terse Markdown body.

- **Self-contained.** A skill depends on nothing outside its own directory, because `npx skills add` copies only that directory, so shared or repo-root files never ship. Every link resolves inside the skill, and the only web links are the tool docs an agent opens to run a tool, which the validator allowlists.
- **Compose by name.** Skills reference each other by name in `## See also` (`build`, `review`, …), never by path, so there are no cross-directory links to break.
- **Terse and imperative.** Each skill states its intent and workflow. No filler.
- **Provider-neutral.** Skills name capability tiers (`fast` / `balanced` / `powerful`), not specific models.

`mise run validate` enforces the mechanical parts, which the repo's [`AGENTS.md`](../AGENTS.md) lists.

## Model tiers

Skills reference three capability tiers instead of provider-specific model names. Map them to whatever you're running:

| Tier | Role | How to pick |
|------|------|---------|
| `fast` | Parallel reads, cheap context gathering | The smallest model in your lineup — the one you'd happily run five of at once |
| `balanced` | Default session model | Whatever you already code with day to day |
| `powerful` | Synthesis, high-stakes analysis, high reasoning effort | The strongest reasoning model you have access to, run at high effort |

Naming actual models here would be wrong within months, so this column gives the rule for choosing rather than the answer. The validator rejects provider model names in the skills, the README and `docs/`.

## Principles

Each principle lives in one place, and the reviewer cites the rule behind each finding.

- **A principle more than one skill applies** lives in [principles](../skills/expertise/principles/SKILL.md), one file each: no comments, Chesterton's Fence, proven able to fail, fix the cause, no transitional architecture, mistake-proofing, no text heuristics, no drift, review report, and verify at the source.
- **The design rules** live in [design-review's patterns](../skills/expertise/design-review/references/patterns.md), in two parts: Architecture, such as one reason to change per module, building only what the job needs (YAGNI), and parsing what crosses a boundary; and Code, such as no abstraction before the third copy (rule of three).
- **The rest** live in the skill that applies them.
