# Agent Skills

Engineering skills for AI coding agents, compatible with [agentskills.io](https://agentskills.io).

I do all my engineering with coding agents, and these skills encode the workflow I follow. They are opinionated, based on 15+ years of building production software.

Two parts carry the workflow:

- **[task](skills/workflow/task/SKILL.md) routes each task.** It picks a route by what the task changes and loads the skill each step needs.
- **[A separate reviewer](#the-reviewer) judges every commit** against my design rules in [design-review](skills/expertise/design-review/SKILL.md).

Builds on [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills); routes adapted from [pstack](https://github.com/cursor/plugins/tree/main/pstack), the plugin from [superpowers](https://github.com/obra/superpowers).

## Three loops

- **The inner loop is one task.** [task](skills/workflow/task/SKILL.md) takes it from request to landed commit, step by step, as [how a task runs](#how-a-task-runs) shows.
- **The outer loop is all the work.** [coordinate](skills/workflow/coordinate/SKILL.md) hands each task to an agent running the inner loop, keeps the agents moving, takes every choice it can recommend and asks me only product tradeoffs and what it cannot answer, and [reports](skills/workflow/coordinate/references/report.md) what is in flight. It keeps its state in a [ledger](#the-plugin), so one long session can run on autocompaction, and a session that dies, or moves to another machine or account, resumes from it.
- **The improvement loop changes the workflow.** The [coach](#the-plugin) reads how past work went, and the coordinator applies each change it proposes as an experiment, with the signal it should move and a check date. On that date, the signal before and after the change decides whether it stays or is reverted or trimmed, as [the improvement loop](#the-improvement-loop) shows.

```mermaid
flowchart LR
  you(["You"]) --> outer["Outer loop"]
  outer --> you
  outer --> inner["Inner loop"]
  inner --> outer
  inner --> improve["Improvement loop"]
  outer --> improve
  improve --> outer
```

[The loops](docs/loops.md) has a chart for each loop, with its handoffs.

## Install

### Claude Code

Install the `cniska-skills` plugin, which bundles every skill with the hooks and the agents described in [the plugin](#the-plugin):

```
claude plugin marketplace add cniska/agent-skills
claude plugin install cniska-skills@cniska
```

- An installed plugin is a copy of the commit it was installed from. `claude plugin update cniska-skills@cniska` brings it up to the marketplace's latest.
- To try it for one session from a checkout, run `claude --plugin-dir .`.
- Skills also installed through `npx skills add` show up a second time without the prefix, so use one or the other.

### Other agents

```
npx skills add cniska/agent-skills
```

### Working on the skills themselves

In Claude Code, add this checkout as the marketplace (`claude plugin marketplace add <path>`) and run `claude plugin update cniska-skills@cniska` after each commit.

For other agents, `mise run link` symlinks every skill from this checkout into `~/.agents/skills` (or `SKILLS_DIR`), so an edit here is live in every agent.

- It removes links to skills that no longer exist.
- It leaves any other file or folder of the same name alone and reports it.
- `mise run link <skill>…` links only the skills you name.

## How a task runs

Start a task with `/task <task>`. The route for that kind of task loads each skill as its step starts, since a skill only helps when something loads it. With [the plugin](#the-plugin), the command is `/cniska-skills:task <task>`.

```text
/task <task>
  → a route, chosen by what the task changes: Feature | Bug fix | Refactor | Test | Review
  → each step loads its skill when the step starts
  → each commit: design-review by a fresh agent
  → the repo's checks → review → land as the repo's rule says
```

`<task>` is what you would tell a colleague, in your own words: one line, an issue to fix, or a brief from a coordinating agent. The route reads the code the task names and works out the rest. A task whose shape is unclear starts with `plan`, which asks before it builds.

```text
/task fix issue #25                          → Bug fix
/task add a --json flag to the sync command  → Feature
/task split the config module by concern     → Refactor
/task cover the retry limit with a test      → Test
/task review PR #41                          → Review
```

Four rules shape every route:

- **The repo's rules win.** A route reads the repo's `AGENTS.md` or `CLAUDE.md` first and defers to it on how to branch, check and land. A repo skill that covers the task or a step takes its place.
- **A route only names the skills; each skill decides how its step is done.** A step whose work does not come up is skipped and named in the report.
- **A task that changes no code has no route.** A question or a doc edit goes straight to its own skill.
- **A skill or agent change takes `skill-writing`**, then the per-commit step, `design-review` by a fresh agent.

| Route | When | Steps |
|---|---|---|
| Feature | New or changed behavior | [feature.md](skills/workflow/task/references/feature.md) |
| Bug fix | Behavior that differs from what it should be | [bug-fix.md](skills/workflow/task/references/bug-fix.md) |
| Refactor | A change to structure that keeps behavior, a redesign, or a removal | [refactor.md](skills/workflow/task/references/refactor.md) |
| Test | A change only to tests, or to the spec wording they prove | [test.md](skills/workflow/task/references/test.md) |
| Review | Someone else's change, or a change that already landed | [review.md](skills/workflow/task/references/review.md) |

## The improvement loop

The workflow changes only on evidence, and a change stays only if it helps. The coach runs [workflow-review](skills/workflow/workflow-review/SKILL.md) to find what to change, and the coordinator applies each change as an [experiment](skills/workflow/coordinate/references/experiments.md).

```mermaid
flowchart LR
  prop["Proposal<br/>with evidence"] --> exp["Experiment<br/>commit, signal, check date"]
  exp --> move["Signals move"]
  move --> check["Check date<br/>before vs after"]
  check --> keep["Keep"]
  check --> revert["Revert or trim"]
  keep --> prop
  revert --> prop
```

An eval I approve can check a change before it lands, and the signals judge it after.

The signals count the friction I feel, per week, repo and route; owner interrupts and time to land weigh most:

- **Owner interrupts:** how often I had to answer, correct or unblock an agent.
- **Time to land:** from my request to the commit on the remote.
- **Review loops:** reviewer runs per commit.
- **Stranded work:** commits not on the remote within an hour of being made.
- **False stops:** a gate that refused work which then went on with nothing the gate checks changed.

[agent-record's spec](https://github.com/cniska/agent-record/blob/main/SPEC.md) defines each signal exactly.

Ideas and evidence come from different places. Upstreams, the repos and people I follow, bring ideas. [agent-record](https://github.com/cniska/agent-record) brings the evidence: the sessions, the hook events, and the signals counted from them. An idea becomes a proposal only when the record shows the friction it answers, or the ledger names the gap.

The loop changes skills, agents, hooks, checks and its upstream lists on its own. Anything else comes to me as a conflict: a change to a repo's `AGENTS.md`, to permissions, to my settled decisions or to how much autonomy the agents have, adding, running or changing an eval, and a new tool.

It follows lean practice, in plain terms first:

- The skills are the standard way of working, and every change the coordinator makes to them is an experiment (kaizen).
- Each finding names what it cost and is traced back to a skill line, a repo rule, a check or a missing tool (waste, 5 whys).
- Rules become checks, as [principles](#principles) says, and a gate that refuses correct work is a defect of the gate (jidoka, false stops).
- An agent that hits a defect stops and reports it rather than working around it, the stop-the-line rule in [principles](#principles) (andon).

[waste-and-cause.md](skills/workflow/workflow-review/references/waste-and-cause.md) has the detail.

## The reviewer

A fresh agent that did not write the work runs [design-review](skills/expertise/design-review/SKILL.md) on each commit, and on the design wherever its shape is open. The agent that made a change never judges how it is built.

- **It judges the way I would in review**, against my design rules: architecture, patterns and code smells.
- **For each problem it states what is wrong and what it should be instead**, so its findings steer the work toward the shape I would have given it.
- **On how code is built, its verdict wins** over other reviewers.

It ranks each finding Fix or Consider:

- **Fix** is a design the next case would copy, or one that misleads the next writer. While a Fix finding stands, the reviewer returns the change. Every Fix finding is fixed, and the re-review judges only the fix.
- **Consider** is local mess. When only Consider findings remain, the reviewer accepts. They are fixed in their own follow-up commit after the accepted one, as is neighboring code the review turns up, never left in a backlog. A finding a re-review raises about other code starts its own fix rather than blocking the accept.

Only a finding that needs my decision, or sits in a change another person owns, goes into the task's report.

## The plugin

This repo is also `cniska-skills`, a Claude Code plugin. It bundles every skill, with the `cniska-skills:` prefix, plus the hooks and agents below.

- **Session-start hook:** sends every task through `task`, so a plain prompt takes the same route as `/task`.
  - A new session is told to start each task with `cniska-skills:task`, to load other skills only as a route directs, and that a commit changing code waits for the reviewer's accept.
  - A resumed, forked or compacted session is told to load `coordinate` again and resume its ledger and workers when it coordinates other agents, or else to reload `task` and re-enter its route.
- **Reviewer agent (`cniska-skills:reviewer`):** judges a design or a change it did not write, as the [reviewer](#the-reviewer).
  - It runs [design-review](skills/expertise/design-review/SKILL.md) read-only, with its skills preloaded, since a subagent starts without the parent's.
  - It ends each report with `Verdict: accept` or `Verdict: return`, naming the repo it judged on a `Repo:` line above it.
- **Commit gate:** blocks a commit until the reviewer has accepted that exact diff, in the worktree the commit targets.
  - An edit after the accept, or a `Verdict: return`, blocks it again.
  - A diff that changes only Markdown needs no accept.
  - The accept counts for the repo the reviewer named, so a session can have a change in another repo reviewed.
- **Ledger hook:** prints the [coordinate](skills/workflow/coordinate/SKILL.md) ledger into context whenever a session starts, clears, resumes, forks or compacts, for the [outer loop](#three-loops).
  - The ledger holds open work, owner decisions, questions waiting on the owner, and a running line per worker naming its brief, filed beside it.
  - When git tracks the ledger, the hook first fast-forwards its checkout from the remote, under a five-second deadline, and says when it could not (offline, diverged, uncommitted changes) and how far behind the printed ledger is.
  - Experiments go in `experiments.jsonl` beside it, one line each time one opens or closes, so agent-record can archive them.
  - It lives at `~/.local/state/agent-skills/ledger.md` by default (under `$XDG_STATE_HOME` when that is set to an absolute path).
  - Set `AGENT_LEDGER` to keep it elsewhere, such as a file in a repo you choose, so it outlives the machine.
- **Coach agent (`cniska-skills:coach`):** finds where the workflow failed me and proposes fixes.
  - It runs [workflow-review](skills/workflow/workflow-review/SKILL.md) over past sessions: my corrections, the questions I had to ask and the friction sessions reported.
  - It proposes only the changes that repeat across sessions.
  - It checks each open experiment past its check date in the record its brief names (the `experiments.jsonl` beside the ledger, passed on by the due note), comparing its signal before and after, and proposes keeping, reverting or trimming the change, a later check date when there is not enough data, or a new start date, with an install if needed, when the change was not installed yet.
  - It also reads what moved in the upstream list its brief names (the `upstreams.json` beside the ledger, passed on by the due note), and proposes an upstream change only when the session record or the ledger already asks for it.
  - It changes nothing itself and runs only read commands, `agent-record sync` and a temporary clone of an upstream.
  - It ends each report with `Proposals: <n>`.
- **Coach schedule:** a session-start hook that tells the agent when the coach is due.
  - The coach is due when a session starts or is cleared more than a day after the last run, or with no run recorded.
  - A run counts once its report ends with `Proposals: <n>`.
  - When the coach is due and `upstreams.json` sits beside the ledger, it also says how many upstreams moved since their last reviewed commit and where the list is, asking each with `git ls-remote` and skipping any that do not answer.
  - When the coach is due and `experiments.jsonl` sits beside the ledger, it also says how many experiments are open, how many of them are past their check date, and where the record is.
  - The agent applies the proposals at the next break, opening an experiment for each change, and brings me only conflicts.
- **Event log:** the hooks append what a session transcript does not show plainly to `events.jsonl` in the plugin's data directory, for [agent-record](https://github.com/cniska/agent-record) to archive.
  - It holds each commit-gate and verdict-check decision with a fixed reason code, each reviewer verdict, each permission prompt and each auto-mode denial.
  - A hook that cannot write the line says so on stderr and decides as it would have.
  - [`hooks/events.md`](hooks/events.md) is the format.

The hooks need `jq`.

How the parts fit together, with the optional [agent-record](https://github.com/cniska/agent-record), [agent-worktree](https://github.com/cniska/agent-worktree) and [agent-gates](https://github.com/cniska/agent-gates) beside the plugin:

```mermaid
flowchart LR
  rec[("agent-record<br/>session record")]
  ups(["Upstreams"])
  wt["agent-worktree<br/>a checkout per task"]
  ledger[("Ledger<br/>a local file, or a repo you choose")]
  agent(["Agent"])
  subgraph S["cniska-skills plugin"]
    hook["Hooks<br/>session, ledger, events"]
    skills["Skills<br/>coordinate, task and its routes"]
    rev["Reviewer agent"]
    gate["Commit gate"]
    coach["Coach agent"]
  end
  subgraph G["agent-gates"]
    hooks["Git hooks"]
    ci["CI checks"]
  end
  ledger --> hook
  hook --> agent
  rec -- "past decisions" --> agent
  wt -- "own checkout" --> agent
  agent --> skills
  skills -- "coordinate rewrites" --> ledger
  skills --> rev
  rev -- "accept" --> gate
  gate --> hooks
  hooks -- "after push" --> ci
  hook -- "event log" --> rec
  rec -- "past sessions, signals" --> coach
  ups -- "ideas" --> coach
  coach -- "proposals" --> agent
```

One commit, start to finish:

```mermaid
sequenceDiagram
  participant A as Agent
  participant V as Reviewer
  participant P as Commit gate
  participant G as Git hooks
  participant C as CI
  A->>A: task picks a route, steps load skills
  A->>V: here is the diff
  V-->>A: Verdict: return, with findings
  A->>V: the fix
  Note over V: judges only the fix, not the whole diff again
  V-->>A: Verdict: accept
  Note over V: the accept is recorded for this diff
  A->>P: git commit
  P->>G: allowed (diff unchanged since accept)
  G-->>A: the project's commit checks pass
  A->>C: push, as the repo's rule says
  C-->>A: same checks again
```

### Optional companions

- **`cniska-record`** keeps the [agent-record](https://github.com/cniska/agent-record) session record current and points the agent at it.
  - Whenever a session starts, resumes, clears or compacts, it runs `agent-record sync` in the background and adds a note to search the record before acting on a handoff, plan or memory.
  - `search-sessions` asks that record first.
  - It does nothing unless the agent-record CLI is on PATH. Install it with `claude plugin install cniska-record@cniska`.
- **`cniska-worktree`** gives each task its own checkout through the [agent-worktree](https://github.com/cniska/agent-worktree) CLI.
  - Whenever a session starts, resumes, clears or compacts, it adds a note telling the agent to create and remove task worktrees with the CLI.
  - Its `WorktreeCreate` and `WorktreeRemove` hooks send Claude Code's own worktrees through the CLI too.
  - Install the CLI first, then `claude plugin install cniska-worktree@cniska`.
- **`cniska-gates`** reports the comments each edit adds, in the words of the [agent-gates](https://github.com/cniska/agent-gates) no-comments gate, before the commit hook refuses them; the committed git hooks still gate every contributor. It does nothing in a repo without the gate. Install it with `claude plugin install cniska-gates@cniska`.

`cniska-skills` works without any of them.

## Skills

**Workflow** — steps that produce an output; one that goes unused is fixed or dropped.

| Skill | Description |
|-------|------------|
| [task](skills/workflow/task/SKILL.md) | Pick a route by what the task changes and load each step's skill |
| [coordinate](skills/workflow/coordinate/SKILL.md) | Run work across agents and repos from a ledger, asking the owner only what it cannot answer |
| [plan](skills/workflow/plan/SKILL.md) | Design through dialogue, slice vertically |
| [spec](skills/workflow/spec/SKILL.md) | State what to build, not how; labelled, traceable requirements |
| [build](skills/workflow/build/SKILL.md) | Vertical slices — implement, verify, commit, repeat |
| [tdd](skills/workflow/tdd/SKILL.md) | Red-green-refactor, one test at a time |
| [debug](skills/workflow/debug/SKILL.md) | Stop the line, reproduce, fix root cause, guard with test |
| [refactor](skills/workflow/refactor/SKILL.md) | Refactor or rewrite so the new design copies nothing from the old |
| [simplify](skills/workflow/simplify/SKILL.md) | Reduce complexity, Chesterton's Fence, preserve behavior |
| [deprecation](skills/workflow/deprecation/SKILL.md) | Build replacement first, migrate consumers, remove completely |
| [git](skills/workflow/git/SKILL.md) | Conventional commits, rebase to sync, squash to land |
| [pr](skills/workflow/pr/SKILL.md) | Self-review gated PR create or description update |
| [ship](skills/workflow/ship/SKILL.md) | Pre-release gate, version bump from commits, cut the tag |
| [review](skills/workflow/review/SKILL.md) | All review dimensions on a diff — self or PR mode |
| [audit](skills/workflow/audit/SKILL.md) | All review dimensions on existing code, read-only, with per-dimension coverage |
| [explain-diff](skills/workflow/explain-diff/SKILL.md) | Explain a diff's intent and risk in the session |
| [second-opinion](skills/workflow/second-opinion/SKILL.md) | Have a different model attack a consequential call or a document's facts |
| [issue](skills/workflow/issue/SKILL.md) | File a GitHub issue — check duplicates, draft, get approval |
| [why](skills/workflow/why/SKILL.md) | Trace recorded design rationale and check whether it still applies |
| [search-sessions](skills/workflow/search-sessions/SKILL.md) | Find what a past session said and decided, quoted and cited; asks [agent-record](https://github.com/cniska/agent-record) first where it is installed |
| [adr](skills/workflow/adr/SKILL.md) | Record an important technical decision by the problem it solves, current state only |
| [docs](skills/workflow/docs/SKILL.md) | Create or update project documentation |
| [agents-md](skills/workflow/agents-md/SKILL.md) | Create or update AGENTS.md project rules |
| [skill-writing](skills/workflow/skill-writing/SKILL.md) | Create or update a skill — clone the closest sibling, keep project specifics out, dry-run blind against a baseline on unlike real repos, score on eval cases where the repo has them |
| [routine-writing](skills/workflow/routine-writing/SKILL.md) | Write a scheduled, unattended agent run: the file as the source, hard limits, loud failures, a probe and a manual run before it runs alone |
| [verification-setup](skills/workflow/verification-setup/SKILL.md) | Create or update a project skill that drives and inspects the running app |
| [workflow-review](skills/workflow/workflow-review/SKILL.md) | Turn how the work actually went into proposed changes to skills, agents and repo rules, each backed by two sessions of quoted evidence and named by the waste it cost and its cause |

**Expertise** — rules for what good looks like in one kind of work; one may go unused for a while.

| Skill | Description |
|-------|------------|
| [principles](skills/expertise/principles/SKILL.md) | The principles more than one skill applies, one file each, read by name |
| [code-writing](skills/expertise/code-writing/SKILL.md) | Shared code rules once, plus a toolchain and pitfalls reference per language |
| [test-writing](skills/expertise/test-writing/SKILL.md) | Tests that catch a named bug, proven able to fail |
| [writing](skills/expertise/writing/SKILL.md) | Write clear, natural prose for each reader and medium, and the shared rules for documents that last |
| [database-design](skills/expertise/database-design/SKILL.md) | Schema as the domain's record: invariants, access, and migrations in the database |
| [ui-design](skills/expertise/ui-design/SKILL.md) | Design or review interfaces against product states and visual hierarchy |
| [design-review](skills/expertise/design-review/SKILL.md) | Judge code against design rules; trace a module's bugs to its design, cuts first |
| [correctness-review](skills/expertise/correctness-review/SKILL.md) | Logic bugs, edge cases, broken contracts |
| [maintainability-review](skills/expertise/maintainability-review/SKILL.md) | Conformance to local conventions, naming and readability |
| [architecture-review](skills/expertise/architecture-review/SKILL.md) | Conformance to the project's stated boundaries, dependency direction and contracts |
| [security-review](skills/expertise/security-review/SKILL.md) | Trust boundaries, execution safety, concrete attack paths only |
| [performance-review](skills/expertise/performance-review/SKILL.md) | Repeated work, unbounded operations, and resource use |
| [test-review](skills/expertise/test-review/SKILL.md) | Coverage gaps, edge cases, test quality |
| [doc-review](skills/expertise/doc-review/SKILL.md) | Drift detection, terminology, outdated names |

## How I maintain these

These are built for my own use, in my own tone and decision style. The goal is consistent execution quality across sessions, not generic prompt patterns.

I run the whole set with an `AGENTS.md` in every repo. Skills defer to it for project-specific facts, such as verify and release commands, invariants and conventions, rather than restating them. Each skill still installs and runs on its own, and falls back to sensible defaults in a repo without one. Use the [agents-md](skills/workflow/agents-md/SKILL.md) skill to create that file first.

What feeds the maintenance: daily use in my own projects, gaps observed in real sessions, selective upstream review as a signal, and external feedback when it aligns with these principles.

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

Each skill is one self-contained directory: `skills/<kind>/<name>/SKILL.md`, where the kind is `workflow` or `expertise`, plus any `references/` files it loads only when a task needs them. `SKILL.md` has YAML frontmatter (`name` matching the directory, `description` starting with an imperative verb) and a terse Markdown body.

- **Self-contained.** A skill depends on nothing outside its own directory, because `npx skills add` copies only that directory, so shared or repo-root files never ship. Every link resolves inside the skill.
- **Compose by name.** Skills reference each other by name in `## See also` (`build`, `review`, …), never by path, so there are no cross-directory links to break.
- **Terse and imperative.** Each skill states its intent and workflow, and ends with a `## Red flags` section of failure modes. No filler.
- **Provider-neutral.** Skills name capability tiers (`fast` / `balanced` / `powerful`), not specific models.

`mise run validate` enforces the mechanical parts: the two kind folders, frontmatter, `## Red flags`, and links that stay inside the skill.

### Model tiers

Skills reference three capability tiers instead of provider-specific model names. Map them to whatever you're running:

| Tier | Role | How to pick |
|------|------|---------|
| `fast` | Parallel reads, cheap context gathering | The smallest model in your lineup — the one you'd happily run five of at once |
| `balanced` | Default session model | Whatever you already code with day to day |
| `powerful` | Synthesis, high-stakes analysis, high reasoning effort | The strongest reasoning model you have access to, run at high effort |

Naming actual models here would be wrong within months, so this column gives the rule for choosing rather than the answer. The validator rejects provider model names in the skills and in this README.

### Principles

Each principle lives in one place, and the reviewer cites the rule behind each finding.

- **A principle more than one skill applies** lives in [principles](skills/expertise/principles/SKILL.md), one file each: no comments, Chesterton's Fence, proven able to fail, fix the cause, no transitional architecture, rules as checks, no drift, and verify at the source.
- **The design rules** live in [design-review's patterns](skills/expertise/design-review/references/patterns.md), in two parts: Architecture, such as one reason to change per module, building only what the job needs (YAGNI), and parsing what crosses a boundary; and Code, such as no abstraction before the third copy (rule of three).
- **The rest** live in the skill that applies them:

| Principle | In practice | Lives in |
|-----------|------------|--------|
| Vertical slices | One complete path through the stack at a time | build, plan |
| Contract first | Schema before implementation | build |
| One change per commit | One logical change per commit | build, git |
| Stop the line | Something breaks — stop, don't push past it | debug |
| Prove-It pattern | Failing test before fix | debug, tdd |
| Mock at boundaries | Mock external systems, not internal functions | test-writing, test-review |
| DAMP over DRY | Descriptive tests over deduplicated tests | test-writing |
| Hyrum's Law | All observable behavior becomes a commitment | deprecation |
| Code as liability | Less code serving the same purpose is better | deprecation |
| Source over memory | Check the installed version's docs, types or source, not memory | build, code-writing |
| Parse, don't cast | Data crossing a boundary becomes a typed value at the edge | code-writing |
| Minimum dependencies | The standard library or a dependency already in the tree before a new one | code-writing |
| Save-point pattern | Commit early when exploring uncertain changes | git |
| Evidence threshold | Concrete references, not speculation | review skills |

### Development

Tasks run through [mise](https://mise.jdx.dev). It also pins `shellcheck`, `jq` for the hook tests, and [Bun](https://bun.sh) for the TypeScript tooling: the eval tooling in `evals/lib/`, and the code it shares with the repo scripts in `lib/`.

```
mise install
mise run bootstrap
```

`mise run bootstrap` installs dependencies and runs validation. Installing runs the `prepare` script, which points Git at [`.githooks/`](.githooks/): the [agent-gates](https://github.com/cniska/agent-gates) `commit-subject`, `format` and `no-comments` gates.

A new worktree runs [`scripts/worktree-setup.sh`](scripts/worktree-setup.sh) under [agent-worktree](https://github.com/cniska/agent-worktree) to trust and install the mise tools and install dependencies; it needs no teardown.

In Claude Code cloud sessions, the proxy blocks mise.run and GitHub release downloads. [`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh) works around that:

- It installs mise from npm and shellcheck from PyPI, and turns off mise's own shellcheck.
- It installs dependencies.
- It installs the `cniska-skills` plugin that [`.claude/settings.json`](.claude/settings.json) enables, since a cloud session does not install it from the settings alone.

The checks:

- `mise run validate` runs [`scripts/validate.ts`](scripts/validate.ts).
- `mise run test` runs the bash and TypeScript tests.
- `mise run lint` runs Biome, `tsc` and the pinned `shellcheck`.

On pull requests and pushes to `main`, [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs `validate`, `lint` and `test`, plus the eval checks that need no model, `test:evals` and `test:triggers`. [`evals/README.md`](evals/README.md) describes them.

- **Commit subjects** are refused on commit by the `commit-msg` hook, and judged for every pushed commit by [`.github/workflows/commits.yml`](.github/workflows/commits.yml).
- **Formatting:** the `pre-commit` hook runs the repo's `format` script, stages what it changes in files the commit stages whole, and refuses a partly staged file it would change, and [`.github/workflows/format.yml`](.github/workflows/format.yml) refuses unformatted files in CI.
- **Comments** in a TypeScript or shell file a commit changes, other than one a tool reads and acts on, such as a shebang, are refused on commit by the `pre-commit` hook and in CI by [`.github/workflows/no-comments.yml`](.github/workflows/no-comments.yml).

Create a new skill with `mise run new-skill <workflow|expertise> <kebab-case-name> "<imperative description>"`, which runs [`./scripts/new-skill.sh`](scripts/new-skill.sh) from [`SKILL_TEMPLATE.md`](SKILL_TEMPLATE.md). `mise tasks` lists every command.

## License

MIT
