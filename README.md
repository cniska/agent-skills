# Agent Skills

Engineering skills for AI coding agents. Compatible with [agentskills.io](https://agentskills.io).

```
(spec →) plan → build → review → ship
```

These cover the software development lifecycle (SDLC) end to end. `spec` is the optional entry point — reach for it when a project needs a written, verifiable contract of what to build, and start at `plan` when it doesn't. From there the phases run in order: plan it, build it, review it, ship it.

I wrote these to work more efficiently with AI coding agents. They are opinionated, based on 15+ years of building production software, and encode the workflow I actually follow. They took shape while building [Acolyte](https://github.com/cniska/acolyte), where generic prompts did not hold up across sessions.

Some ideas were refined after reviewing [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) and [pstack](https://github.com/cursor/plugins/tree/main/pstack).

## Motivation

This repo exists to encode a practical engineering workflow for AI coding agents in my own tone and decision style. The goal is consistent execution quality across sessions, not generic prompt patterns.

These are built for my own use, and I run the whole set with an `AGENTS.md` in every repo. That file is the grounding hub: skills defer to it for project-specific facts (verify and release commands, invariants, conventions) rather than restating them. Each skill still installs and runs on its own, but it's designed assuming the set and an `AGENTS.md` are present — install a lone skill into a repo without one and it falls back to sensible defaults rather than project truth. Use the [`agents-md`](skills/agents-md/SKILL.md) skill to create that hub first.

## How I update these skills

Maintenance inputs: daily use in my own projects, gaps observed in real sessions, selective upstream review (for example Addy updates) as a signal, and external feedback when it aligns with these principles.

I add guidance when it:

- repeats in real work
- improves quality, speed, or risk profile
- can be verified with concrete checks
- fits the way I want agents to operate

I remove or simplify guidance when it:

- no longer changes outcomes
- becomes outdated
- duplicates other skills
- drifts toward generic "corp" voice without adding value

## Install

```
npx skills add cniska/skills
```

To work on the skills themselves, `mise run link` symlinks every skill from this checkout into `~/.agents/skills` (or `SKILLS_DIR`), so an edit here is live in every agent. It removes links to skills that no longer exist, and leaves any other file or folder of the same name alone, reporting it. `mise run link <skill>…` links only those.

### Claude Code on the web

Cloud sessions start in a fresh container, so install the skills from the environment's setup script (environment settings → Setup script). It runs before the session starts, so the skills are in place when it does:

```
npx -y skills add cniska/skills -g -a claude-code -s '*' -y --copy
```

`-g` installs user-level (`~/.claude/skills`), so every repo in the session gets the set; `-s '*'` takes every skill, and `-y` skips the prompts a setup script can't answer.

## Local setup

Tasks run through [mise](https://mise.jdx.dev), which also pins `shellcheck`:

```
mise install
mise run bootstrap
```

`mise run bootstrap` configures Git hooks and runs validation.

Active pre-push hook: [`.githook/pre-push`](.githook/pre-push).

## Skills

| Phase | Skill | Description |
|-------|-------|------------|
| **Plan** | [spec](skills/spec/SKILL.md) | State what to build, not how; labelled, traceable requirements |
| | [plan](skills/plan/SKILL.md) | Design through dialogue, slice vertically |
| | [ui-design](skills/ui-design/SKILL.md) | Design or review interfaces against product states and visual hierarchy |
| | [database-design](skills/database-design/SKILL.md) | Schema as the domain's record: invariants, access, and migrations in the database |
| **Build** | [build](skills/build/SKILL.md) | Vertical slices — implement, verify, commit, repeat |
| | [code-writing](skills/code-writing/SKILL.md) | Shared code rules once, plus a toolchain and pitfalls reference per language |
| | [tdd](skills/tdd/SKILL.md) | Red-green-refactor, one test at a time |
| | [test-writing](skills/test-writing/SKILL.md) | Tests that catch a named bug, proven able to fail |
| | [debug](skills/debug/SKILL.md) | Stop the line, reproduce, fix root cause, guard with test |
| | [refactor](skills/refactor/SKILL.md) | Refactor or rewrite so the new design copies nothing from the old |
| | [simplify](skills/simplify/SKILL.md) | Reduce complexity, Chesterton's Fence, preserve behavior |
| | [git](skills/git/SKILL.md) | Conventional commits, rebase to sync, squash to land |
| | [deprecation](skills/deprecation/SKILL.md) | Build replacement first, migrate consumers, remove completely |
| **Review** | [explain-diff](skills/explain-diff/SKILL.md) | Explain a diff's intent and risk in the session |
| | [review](skills/review/SKILL.md) | All review dimensions on a diff — self or PR mode |
| | [audit](skills/audit/SKILL.md) | All review dimensions on existing code, read-only, with per-dimension coverage |
| | [design-review](skills/design-review/SKILL.md) | Judge code against design rules; trace a module's bugs to its design, cuts first |
| | [correctness-review](skills/correctness-review/SKILL.md) | Logic bugs, edge cases, broken contracts |
| | [maintainability-review](skills/maintainability-review/SKILL.md) | Conformance to local conventions, naming and readability |
| | [architecture-review](skills/architecture-review/SKILL.md) | Conformance to the project's stated boundaries, dependency direction and contracts |
| | [security-review](skills/security-review/SKILL.md) | Trust boundaries, execution safety, concrete attack paths only |
| | [performance-review](skills/performance-review/SKILL.md) | Repeated work, unbounded operations, and resource use |
| | [test-review](skills/test-review/SKILL.md) | Coverage gaps, edge cases, test quality |
| | [doc-review](skills/doc-review/SKILL.md) | Drift detection, terminology, outdated names |
| **Ship** | [ship](skills/ship/SKILL.md) | Pre-release gate, version bump from commits, cut the tag |
| **Meta** | [agents-md](skills/agents-md/SKILL.md) | Create or update AGENTS.md project rules |
| | [docs](skills/docs/SKILL.md) | Create or update project documentation |
| | [adr](skills/adr/SKILL.md) | Record an important technical decision by the problem it solves, current state only |
| | [issue](skills/issue/SKILL.md) | File a GitHub issue — check duplicates, draft, get approval |
| | [pr](skills/pr/SKILL.md) | Self-review gated PR create or description update |
| | [handoff](skills/handoff/SKILL.md) | Brief the next session on the next move, then reset context |
| | [search-sessions](skills/search-sessions/SKILL.md) | Find what a past session said and decided, quoted and cited |
| | [why](skills/why/SKILL.md) | Trace recorded design rationale and check whether it still applies |
| | [second-opinion](skills/second-opinion/SKILL.md) | Have a different model attack a consequential call or a document's facts |
| | [verification-setup](skills/verification-setup/SKILL.md) | Create or update a project skill that drives and inspects the running app |
| | [writing](skills/writing/SKILL.md) | Write clear, natural prose for each reader and medium, and the shared rules for documents that last |
| | [skill-writing](skills/skill-writing/SKILL.md) | Create or update a skill — clone the closest sibling, validate, dry-run |
| | [skill-test](skills/skill-test/SKILL.md) | Dry-run a changed skill on unlike real repos before publishing |

## Design

Each skill is one self-contained directory — `skills/<name>/SKILL.md`, with YAML frontmatter (`name` matching the directory, `description` starting with an imperative verb) and a terse Markdown body, plus any `references/` files it loads only when a task needs them. A few conventions hold across the set:

- **Self-contained.** A skill depends on nothing outside its own directory — `npx skills add` copies only that skill's directory, so shared or repo-root files never ship. Every link resolves inside the skill.
- **Compose by name.** Skills reference each other by name in `## See also` (`build`, `review`, …), never by path — no cross-directory links to break.
- **Terse and imperative.** Intent, workflow, and a `## Red flags` section of failure modes. No filler.
- **Provider-neutral.** Skills name capability tiers (`fast` / `balanced` / `powerful`), not specific models — see below.

`mise run validate` enforces the mechanical parts (frontmatter, `## Red flags`, links that stay inside the skill).

## Model tiers

Skills reference three capability tiers instead of provider-specific model names. Map them to whatever you're running:

| Tier | Role | How to pick |
|------|------|---------|
| `fast` | Parallel reads, cheap context gathering | The smallest model in your lineup — the one you'd happily run five of at once |
| `balanced` | Default session model | Whatever you already code with day to day |
| `powerful` | Synthesis, high-stakes analysis, high reasoning effort | The strongest reasoning model you have access to, run at high effort |

Naming actual models here would be wrong within months, so this column gives the rule for choosing rather than the answer. The validator rejects provider model names anywhere in the repo.

## Principles

| Principle | In practice | Skills |
|-----------|------------|--------|
| Vertical slices | One complete path through the stack at a time | build, plan |
| Contract first | Schema before implementation | build |
| SRP | One responsibility per module, one change per commit | design-review, build, git |
| YAGNI | Don't build for hypothetical requirements | design-review |
| Stop the line | Something breaks — stop, don't push past it | debug |
| Prove-It pattern | Failing test before fix | debug, tdd |
| Mock at boundaries | Mock external systems, not internal functions | test-writing, test-review |
| DAMP over DRY | Descriptive tests over deduplicated tests | test-writing |
| Rule of 3 | Extract after three instances, not before — though a substantial block earns a name on its second | simplify, design-review |
| Chesterton's Fence | Understand before removing | simplify, design-review |
| Hyrum's Law | All observable behavior becomes a commitment | deprecation |
| Code as liability | Less code serving the same purpose is better | deprecation |
| Source over memory | Verify framework behavior in primary docs before implementation | build, code-writing |
| Parse, don't cast | Data crossing a boundary becomes a typed value at the edge | code-writing |
| Minimum dependencies | The standard library or a dependency already in the tree before a new one | code-writing |
| Rules as checks | A mechanical rule is a type, lint or test, not a sentence | code-writing, agents-md |
| No comments | A why goes into a name, a test or the doc that owns the subject | code-writing, agents-md |
| Proven able to fail | Break a check once and watch it go red before trusting it | test-writing, code-writing |
| Save-point pattern | Commit early when exploring uncertain changes | git |
| Evidence threshold | Concrete references, not speculation | review skills |

## Validate skills

Run the validator before publishing changes:

```
mise run validate
```

`mise run validate` runs [`./scripts/validate.sh`](scripts/validate.sh); `mise run test` runs the bash unit tests; `mise run lint` runs the pinned `shellcheck`.

CI runs all three — validate, lint, test — on pull requests and pushes to `main` via [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Commit messages are enforced locally by the pre-push hook (see Local setup).

## Create a new skill

```
mise run new-skill <kebab-case-name> "<imperative description>"
```

`mise run new-skill` is the supported command. It runs [`./scripts/new-skill.sh`](scripts/new-skill.sh) under the hood.

For all available commands:

```
mise tasks
```

Bootstrap script: [`./scripts/bootstrap.sh`](scripts/bootstrap.sh)

Template reference: [`SKILL_TEMPLATE.md`](SKILL_TEMPLATE.md).

## License

MIT
