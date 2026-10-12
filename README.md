# Agent Skills

Engineering skills for AI coding agents, run by the [coordinate](skills/coordinate/SKILL.md) skill: it routes each task through the skills it needs and has a reviewer judge every commit. Compatible with [agentskills.io](https://agentskills.io).

I wrote these to work more efficiently with AI coding agents. They are opinionated, based on 15+ years of building production software, and encode the workflow I actually follow. They took shape through real work with agents, where generic prompts did not hold up across sessions.

The project started from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills), took its routes from [pstack](https://github.com/cursor/plugins/tree/main/pstack), and its plugin from [superpowers](https://github.com/obra/superpowers), each adapted to the way I work.

## How a task runs

A skill only helps when something loads it. Start a task with `/coordinate <task>`, and the route for that kind of task loads each skill as its step starts:

```text
/coordinate <task>
  → a route, chosen by what the task changes: Feature | Bug fix | Refactor | Review | Resume
  → each step loads its skill when the step starts
  → each commit: simplify → design-review by a fresh agent
  → the repo's checks → review → land as the repo's rule says
```

`<task>` is what you would tell a colleague, in your own words: one line, an issue to fix, or a handoff from an earlier session. The route reads the code the task names and works out the rest; a task whose shape is unclear starts with `plan`, which asks before it builds.

```text
/coordinate fix issue #25                          → Bug fix
/coordinate add a --json flag to the sync command  → Feature
/coordinate split the config module by concern     → Refactor
/coordinate review PR #41                          → Review
/coordinate <a handoff pasted from the last session> → Resume
```

With [the plugin](#the-plugin) installed you can skip the command: a hook tells every session to start each task with `coordinate`, so a plain prompt takes the same route.

- **The repo's rules win.** A route reads the repo's `AGENTS.md` first and defers to it on how to branch, check and land; a repo skill that covers the task or a step takes its place.
- **A route names skills, and each skill owns its step.** A step whose work does not come up is skipped and named in the report.
- **A task that changes no code has no route.** A question or a doc edit goes straight to its own skill.

| Route | When | Steps |
|---|---|---|
| Feature | New or changed behavior | [feature.md](skills/coordinate/references/feature.md) |
| Bug fix | Behavior that differs from what it should be | [bug-fix.md](skills/coordinate/references/bug-fix.md) |
| Refactor | A change to structure that keeps behavior, a redesign, or a removal | [refactor.md](skills/coordinate/references/refactor.md) |
| Review | Someone else's change, or a change that already landed | [review.md](skills/coordinate/references/review.md) |
| Resume | After context compaction, or when a session picks up earlier work | [resume.md](skills/coordinate/references/resume.md) |

## The reviewer

[design-review](skills/design-review/SKILL.md) holds code to my design rules: architecture, patterns and code smells. I distilled them from the code I wrote and reviewed before agents, principles I have followed for over a decade. The reviewer judges a change the way I would in review, and its findings steer the work toward the shape I would have given it myself: it states what is wrong and what it should be instead. It returns a change while a design the next case would copy, or one that misleads the next writer, stands, and accepts one whose only remaining findings are local mess, listed for me to weigh. The routes run it in a fresh agent that did not write the work, on each commit and on the design wherever the shape is open, so the agent that made a change never judges how it is built. On how code is built, its verdict wins over other reviewers.

## The plugin

This repo is also `cniska-skills`, a Claude Code plugin that bundles every skill with the hooks and the reviewer agent that keep the routes in force when nobody is watching the session. In Claude Code its skills carry the plugin's prefix, so a task starts with `/cniska-skills:coordinate <task>`.

- **A session-start hook** tells every new session to start each task with `cniska-skills:coordinate` and to load other skills only as it, or a skill it loads, directs, and every resumed, forked or compacted session to take its Resume route.
- **`cniska-skills:reviewer`** runs [design-review](skills/design-review/SKILL.md) as a read-only agent that judges a design or a change it did not write, and ends each report with the repo it judged on a `Repo:` line and `Verdict: accept` or `Verdict: return`. It preloads its skills, since a subagent starts without the parent's.
- **A context check** runs on each prompt and, once the session's context passes 200k tokens, tells the agent to offer a handoff at the next step boundary, once per session. It reads token usage from the session transcript, whose format is internal to Claude Code; when that format changes, it warns on stderr and says nothing to the agent.
- **A commit gate** blocks any `git commit` whose diff changes more than Markdown until `cniska-skills:reviewer` has accepted that exact diff, in the worktree the commit targets. The accept goes to the repo the reviewer's report names on its `Repo:` line, so a session can review a change in another repo. An edit after the accept, or a `Verdict: return`, blocks it again. The gate needs `jq`.

How the parts fit together, with the optional [agent-record](https://github.com/cniska/agent-record) and [agent-gates](https://github.com/cniska/agent-gates) beside the plugin:

```mermaid
flowchart LR
  rec[("agent-record<br/>session record")]
  agent(["Agent"])
  subgraph S["cniska-skills plugin"]
    hook["Session start hook"]
    skills["Skills: coordinate + routes"]
    rev["Reviewer agent"]
    gate["Commit gate"]
  end
  subgraph G["agent-gates"]
    hooks["Git hooks"]
    ci["CI checks"]
  end
  hook --> agent
  rec -- "past decisions" --> agent
  agent --> skills
  skills --> rev
  rev -- "accept" --> gate
  gate --> hooks
  hooks -- "push" --> ci
```

One commit, start to finish:

```mermaid
sequenceDiagram
  participant A as Agent
  participant V as Reviewer
  participant P as Commit gate
  participant G as Git hooks
  participant C as CI
  A->>A: coordinate picks a route, steps load skills
  A->>V: here is the diff
  V-->>A: Verdict: return, with findings
  A->>V: the fix
  Note over V: judges only the fix, not the whole diff again
  V-->>P: Verdict: accept
  A->>P: git commit
  P->>G: allowed (diff unchanged since accept)
  G-->>A: the project's commit checks pass
  A->>C: push
  C-->>A: same checks again
```

Install it:

```
claude plugin marketplace add cniska/agent-skills
claude plugin install cniska-skills@cniska
```

`cniska-record` is optional. Where the [agent-record](https://github.com/cniska/agent-record) CLI is on PATH, it starts `agent-record sync` in the background whenever a session starts, resumes, clears or compacts, and adds a note to search the record before acting on a handoff, plan or memory; `search-sessions` asks that record first. Install it with `claude plugin install cniska-record@cniska`; `cniska-skills` works without it.

`cniska-worktrees` is optional. Where the [agent-worktrees](https://github.com/cniska/agent-worktrees) CLI is on PATH and the project has an executable `scripts/worktree-setup.sh`, it adds a note whenever a session starts, resumes, clears or compacts, telling the agent to open and remove task worktrees with the CLI. Install it with `claude plugin install cniska-worktrees@cniska`; `cniska-skills` works without it.

An installed plugin is a copy of the commit it was installed from; `claude plugin update cniska-skills@cniska` brings it up to the marketplace's latest. Try it for one session from a checkout with `claude --plugin-dir .`. Skills also installed through `npx skills add` show up a second time without the prefix, so use one or the other.

## Skills

Grouped by where the routes use them.

**Shaping the work**

| Skill | Description |
|-------|------------|
| [plan](skills/plan/SKILL.md) | Design through dialogue, slice vertically |
| [spec](skills/spec/SKILL.md) | State what to build, not how; labelled, traceable requirements |
| [ui-design](skills/ui-design/SKILL.md) | Design or review interfaces against product states and visual hierarchy |
| [database-design](skills/database-design/SKILL.md) | Schema as the domain's record: invariants, access, and migrations in the database |

**Writing code**

| Skill | Description |
|-------|------------|
| [code-writing](skills/code-writing/SKILL.md) | Shared code rules once, plus a toolchain and pitfalls reference per language |
| [build](skills/build/SKILL.md) | Vertical slices — implement, verify, commit, repeat |
| [tdd](skills/tdd/SKILL.md) | Red-green-refactor, one test at a time |
| [test-writing](skills/test-writing/SKILL.md) | Tests that catch a named bug, proven able to fail |
| [debug](skills/debug/SKILL.md) | Stop the line, reproduce, fix root cause, guard with test |
| [refactor](skills/refactor/SKILL.md) | Refactor or rewrite so the new design copies nothing from the old |
| [simplify](skills/simplify/SKILL.md) | Reduce complexity, Chesterton's Fence, preserve behavior |
| [git](skills/git/SKILL.md) | Conventional commits, rebase to sync, squash to land |
| [deprecation](skills/deprecation/SKILL.md) | Build replacement first, migrate consumers, remove completely |

**Judging the work**

| Skill | Description |
|-------|------------|
| [design-review](skills/design-review/SKILL.md) | Judge code against design rules; trace a module's bugs to its design, cuts first |
| [review](skills/review/SKILL.md) | All review dimensions on a diff — self or PR mode |
| [correctness-review](skills/correctness-review/SKILL.md) | Logic bugs, edge cases, broken contracts |
| [maintainability-review](skills/maintainability-review/SKILL.md) | Conformance to local conventions, naming and readability |
| [architecture-review](skills/architecture-review/SKILL.md) | Conformance to the project's stated boundaries, dependency direction and contracts |
| [security-review](skills/security-review/SKILL.md) | Trust boundaries, execution safety, concrete attack paths only |
| [performance-review](skills/performance-review/SKILL.md) | Repeated work, unbounded operations, and resource use |
| [test-review](skills/test-review/SKILL.md) | Coverage gaps, edge cases, test quality |
| [doc-review](skills/doc-review/SKILL.md) | Drift detection, terminology, outdated names |
| [explain-diff](skills/explain-diff/SKILL.md) | Explain a diff's intent and risk in the session |
| [second-opinion](skills/second-opinion/SKILL.md) | Have a different model attack a consequential call or a document's facts |
| [principles](skills/principles/SKILL.md) | The principles more than one skill applies, one file each, read by name |

**Landing it**

| Skill | Description |
|-------|------------|
| [pr](skills/pr/SKILL.md) | Self-review gated PR create or description update |
| [ship](skills/ship/SKILL.md) | Pre-release gate, version bump from commits, cut the tag |

**Used on their own**

| Skill | Description |
|-------|------------|
| [handoff](skills/handoff/SKILL.md) | Brief the next session on the next move, offered at a clean break |
| [why](skills/why/SKILL.md) | Trace recorded design rationale and check whether it still applies |
| [search-sessions](skills/search-sessions/SKILL.md) | Find what a past session said and decided, quoted and cited; asks [agent-record](https://github.com/cniska/agent-record) first where it is installed |
| [audit](skills/audit/SKILL.md) | All review dimensions on existing code, read-only, with per-dimension coverage |
| [issue](skills/issue/SKILL.md) | File a GitHub issue — check duplicates, draft, get approval |
| [agents-md](skills/agents-md/SKILL.md) | Create or update AGENTS.md project rules |
| [docs](skills/docs/SKILL.md) | Create or update project documentation |
| [adr](skills/adr/SKILL.md) | Record an important technical decision by the problem it solves, current state only |
| [writing](skills/writing/SKILL.md) | Write clear, natural prose for each reader and medium, and the shared rules for documents that last |
| [verification-setup](skills/verification-setup/SKILL.md) | Create or update a project skill that drives and inspects the running app |
| [skill-writing](skills/skill-writing/SKILL.md) | Create or update a skill — clone the closest sibling, keep project specifics out, dry-run blind against a baseline on unlike real repos, score on eval cases where the repo has them |

## Install

In Claude Code, install [the plugin](#the-plugin). For other agents:

```
npx skills add cniska/agent-skills
```

To work on the skills themselves in Claude Code, add this checkout as the marketplace (`claude plugin marketplace add <path>`) and run `claude plugin update cniska-skills@cniska` after each commit. For other agents, `mise run link` symlinks every skill from this checkout into `~/.agents/skills` (or `SKILLS_DIR`), so an edit here is live in every agent. It removes links to skills that no longer exist, and leaves any other file or folder of the same name alone, reporting it. `mise run link <skill>…` links only those.

### Claude Code on the web

Cloud sessions start in a fresh container, so install the skills from the environment's setup script (environment settings → Setup script). It runs before the session starts, so the skills are in place when it does:

```
npx -y skills add cniska/agent-skills -g -a claude-code -s '*' -y --copy
```

`-g` installs user-level (`~/.claude/skills`), so every repo in the session gets the set; `-s '*'` takes every skill, and `-y` skips the prompts a setup script can't answer.

## How I maintain these

These are built for my own use, in my own tone and decision style; the goal is consistent execution quality across sessions, not generic prompt patterns. I run the whole set with an `AGENTS.md` in every repo. That file is the grounding hub: skills defer to it for project-specific facts (verify and release commands, invariants, conventions) rather than restating them. Each skill still installs and runs on its own, and falls back to sensible defaults in a repo without one. Use the [agents-md](skills/agents-md/SKILL.md) skill to create that hub first.

Maintenance inputs: daily use in my own projects, gaps observed in real sessions, selective upstream review as a signal, and external feedback when it aligns with these principles.

I add guidance when it:

- repeats in real work
- improves quality, speed, or risk profile
- can be verified with concrete checks
- fits the way I want agents to operate

I remove or simplify guidance when it:

- no longer changes outcomes, often because models now do it without being told
- becomes outdated
- duplicates other skills
- drifts toward generic "corp" voice without adding value

Where a rule must hold, I enforce the outcome rather than every step: the reviewer judges the result, and the routes keep only the steps that change it.

## Reference

### Skill conventions

Each skill is one self-contained directory — `skills/<name>/SKILL.md`, with YAML frontmatter (`name` matching the directory, `description` starting with an imperative verb) and a terse Markdown body, plus any `references/` files it loads only when a task needs them.

- **Self-contained.** A skill depends on nothing outside its own directory — `npx skills add` copies only that skill's directory, so shared or repo-root files never ship. Every link resolves inside the skill.
- **Compose by name.** Skills reference each other by name in `## See also` (`build`, `review`, …), never by path — no cross-directory links to break.
- **Terse and imperative.** Intent, workflow, and a `## Red flags` section of failure modes. No filler.
- **Provider-neutral.** Skills name capability tiers (`fast` / `balanced` / `powerful`), not specific models.

`mise run validate` enforces the mechanical parts (frontmatter, `## Red flags`, links that stay inside the skill).

### Model tiers

Skills reference three capability tiers instead of provider-specific model names. Map them to whatever you're running:

| Tier | Role | How to pick |
|------|------|---------|
| `fast` | Parallel reads, cheap context gathering | The smallest model in your lineup — the one you'd happily run five of at once |
| `balanced` | Default session model | Whatever you already code with day to day |
| `powerful` | Synthesis, high-stakes analysis, high reasoning effort | The strongest reasoning model you have access to, run at high effort |

Naming actual models here would be wrong within months, so this column gives the rule for choosing rather than the answer. The validator rejects provider model names anywhere in the repo.

### Principles

Each principle lives in one place. A principle more than one skill applies lives in [principles](skills/principles/SKILL.md), one file each; the rest live in the skill that applies them. The reviewer cites the rule behind each finding.

| Principle | In practice | Lives in |
|-----------|------------|--------|
| No comments | A why goes into a name, a test or the doc that owns the subject | principles |
| Chesterton's Fence | Understand before removing | principles |
| Proven able to fail | Break a check once and watch it go red before trusting it | principles |
| Fix the cause | Remove the state that causes a failure, never guard in front of it | principles |
| No transitional architecture | Replace, migrate and remove; never keep the old path alive | principles |
| Rules as checks | A mechanical rule is a type, lint or test, not a sentence | principles |
| No drift | A change updates everything that describes, repeats, names or depends on what it changed | principles |
| Verify at the source | Check every factual claim where it is defined and cite it | principles |
| Vertical slices | One complete path through the stack at a time | build, plan |
| Contract first | Schema before implementation | build |
| SRP | One responsibility per module, one change per commit | design-review, build, git |
| YAGNI | Don't build for hypothetical requirements | design-review |
| Stop the line | Something breaks — stop, don't push past it | debug |
| Prove-It pattern | Failing test before fix | debug, tdd |
| Mock at boundaries | Mock external systems, not internal functions | test-writing, test-review |
| DAMP over DRY | Descriptive tests over deduplicated tests | test-writing |
| Rule of 3 | Extract after three instances, not before — though a substantial block earns a name on its second | simplify, design-review |
| Hyrum's Law | All observable behavior becomes a commitment | deprecation |
| Code as liability | Less code serving the same purpose is better | deprecation |
| Source over memory | Verify framework behavior in primary docs before implementation | build, code-writing |
| Parse, don't cast | Data crossing a boundary becomes a typed value at the edge | code-writing |
| Minimum dependencies | The standard library or a dependency already in the tree before a new one | code-writing |
| Save-point pattern | Commit early when exploring uncertain changes | git |
| Evidence threshold | Concrete references, not speculation | review skills |

### Development

Tasks run through [mise](https://mise.jdx.dev), which also pins `shellcheck` and [Bun](https://bun.sh) for the TypeScript tooling: the eval tooling in `evals/lib/`, and the code it shares with the repo scripts in `lib/`:

```
mise install
mise run bootstrap
```

`mise run bootstrap` installs dependencies and runs validation. Installing runs the `prepare` script, which points Git at [`.githooks/`](.githooks/), the [agent-gates](https://github.com/cniska/agent-gates) `commit-subject`, `no-comments-javascript` and `no-comments-shell` gates.

In Claude Code cloud sessions, [`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh) installs mise from npm and shellcheck from PyPI, and turns off mise's own shellcheck, because the cloud proxy blocks mise.run and GitHub release downloads.

`mise run validate` runs [`scripts/validate.ts`](scripts/validate.ts); `mise run test` runs the bash and TypeScript tests; `mise run lint` runs Biome, `tsc` and the pinned `shellcheck`. CI runs all three on pull requests and pushes to `main` via [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Commit subjects are refused on commit by the `commit-msg` hook, and judged for every pushed commit by [`.github/workflows/commits.yml`](.github/workflows/commits.yml). A comment in a TypeScript or shell file a commit changes, other than a tool directive, is refused on commit by the `pre-commit` hook and in CI by [`.github/workflows/no-comments.yml`](.github/workflows/no-comments.yml).

Create a new skill with `mise run new-skill <kebab-case-name> "<imperative description>"`, which runs [`./scripts/new-skill.sh`](scripts/new-skill.sh) from [`SKILL_TEMPLATE.md`](SKILL_TEMPLATE.md). `mise tasks` lists every command.

## License

MIT
