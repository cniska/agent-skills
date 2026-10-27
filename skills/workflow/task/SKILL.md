---
name: task
description: Run one task along the route its kind needs — feature, bug fix, refactor, test or review — on its own branch, loading each step's skill in order (a feature plans the design, validates it, then builds). Use at the start of any task that changes code or reviews a change, and again to re-enter its route after a host resume or fork. A skill, loaded with the Skill tool; not a host's Task tool.
argument-hint: "<task>"
---

# Task

A skill runs only when something loads it, and this one is a skill: load it with the Skill tool, never through a host tool named Task. Pick the task's route and work through its steps, loading each step's skill when the step starts. A route names skills; each skill owns how its step is done.

## Pick the route

1. **Read the request and the repo's rules and conventions**: its `AGENTS.md` or `CLAUDE.md`, `CONTRIBUTING`, recent history and merged pull requests. Every task in every repo runs the same way: it works on a topic branch in its own worktree, commits each slice there once `design-review`, and on an interface `ui-review`, accepts it, editing nothing for the next slice until that commit is made, since an accept holds only for the uncommitted changes exactly as they were judged, and lands as a whole once `review` by one fresh agent accepts the branch; slices never land on the default branch one by one. The repo's rules decide only the rest: branch naming, whether and when the branch is pushed, rebase or merge onto the branch it lands on, commit style, and the landing route, straight to the default branch by a fast-forward or merge as the repo does it, or a pull request through `pr`. Where those leave a choice open, ask the user once instead of guessing; a worker asks whoever coordinates it. A repo skill that covers a step takes that step's place; the topic branch, its per-slice commits and landing as a whole still hold.
2. **Match the route by what the task changes**, read from the code it names, not by its wording. A code change always has a route. A change to a skill or agent goes through `skill-writing`, then Close. A task that changes no code, such as a question, goes straight to its own skill; a doc edit goes to `docs-writing`, loaded before the doc's first edit.
3. **Load each step's skill with the Skill tool when the step starts**: this set's skill, not a host skill or tool that shares its name. Skip a step only when its work does not arise, such as `second-opinion` on a design the brief decided rather than one the agent proposed, or one already challenged; a change that looks small still takes every step its work reaches.
4. **`design-review`, and `ui-review` on an interface, runs in a fresh agent that did not write the work**, briefed with the diff or design in a file it reads, each file named in the brief by its absolute path and written to the worker's own temp folder so a parallel worker cannot overwrite it, and every decision the owner or the coordinator settled, a plan included. Wait for its verdict before going on. A return's findings are all fixed and re-reviewed until accept, which comes only when no finding stands, its follow-ups aside; each re-review is another fresh agent given the fix's diff, the change since the diff that returned, in a new file, and the change's earlier diff files, and for `ui-review` fresh captures and frame dumps from a run of the fixed build beside the earlier ones, judging the fix and reading the earlier diffs both for its accept, which then covers the whole change, and to raise findings, never a message to the agent that returned, for `review` and `ui-review` as for `design-review`. A later review of the change, the branch `review`'s first pass or a later `design-review` included, that disagrees with lines an earlier review of it read and left unflagged, whether that review accepted or returned, and is against no decision the owner or the coordinator settled, raises a finding, which returns. After a third return on one commit, stop fixing that commit: save its diff in your temp folder, go on with the commits that do not depend on it, and report it to whoever coordinates you, or else the owner, with what the three returns show, such as a finding that recurs or a fix that keeps moving the defect, and the one decision that would end them. The branch lands without it only when it fixes nothing the branch introduced; otherwise the branch waits for whoever coordinates you, or else the owner. On how the code is built, `design-review` wins over other reviewers; a finding that clashes with a settled decision goes to the owner as a conflict, not a finding.
5. **Re-route when the task changes kind**, and say so.
6. **Fix what the change touches, and queue real defects beyond it**, sorting each where the review report in `principles` puts it. A finding on code no diff of the change touches, which returns the change only because it blocks it, is fixed in a commit of its own that carries only that code, reviewed alone and made before the returned change, whose re-review then takes that commit's diff as the fix, so the change's own diff never grows to cover a neighbor. A follow-up goes to the report for whoever coordinates you, or else the owner, to queue, never into a ledger or a doc; a nit beyond the change is dropped. Code found any other way, not through a review, follows the same rule. Another agent's work on the owner's machine counts as the owner's; an owner decision, or a change another person owns, goes to the report.
7. **Stop at a defect in a tool, hook or gate** rather than working around it: when one refuses correct work or misbehaves, report it, with the command and what it said, to whoever coordinates you, or else the owner, and go on only with work it does not block. Rewording a command until a check stops matching it, or reshaping a change to slip past a gate, is a workaround.
8. **State the report before handing back.** A delegated worker states its report in a message, so its transcript keeps it if the run is cut short, and hands back.
9. **Re-enter the route when the host resumes or forks the session**: the session still holds its own context, so load `task` again, rebuild the route and step from the checkout (`git worktree list`, `git status`, `git log`), then load the current step's skill, and `code-writing` before any further edit. A plan that lives only in a message goes to the repo first. Picking up another session's work is `coordinate`'s resume, not this.

## Report

- Outcome first, then what needs the owner's decision; the rest in short bullets.
- A working agent sends owner questions to whoever coordinates it and goes on with work that does not depend on them.
- Name the route, and every step skipped or not yet run.
- Several asks in one request: answer each by name, so none is dropped.
- After changes, name every choice the owner did not ask for.
- After Close, quote the `branch <name> kept, <reason>` line the worktree removal printed, where it printed one.
- After landing, link the landed commit's green CI runs, or say the repo has no CI, judged from its workflow files and never from an empty run list.

## Shared steps

Every route that changes code runs its own steps between these, and names them where they fall:

- **Open:** the task's own worktree and branch, named as the repo names branches, and `code-writing` before the first edit, with `database-design` or `ui-design` when the change touches a schema or an interface, `test-writing` before the first edit to a test file, with proven able to fail from `principles`, `docs-writing` before the first edit to a doc, and `writing` before the first edit to a spec, rules file or other prose.
- **Challenge:** `second-opinion` on the design the agent proposed, by a `researcher` agent where the host can start one, then `design-review` of the result by a fresh agent.
- **Close:** `design-review` by a fresh agent on each commit before it is made on the branch, and on each commit that changes an interface `ui-review` as well, by a `designer` agent where the host can start one, else by a fresh subagent that loads `ui-review` with the Skill tool, briefed by absolute path with the commit's diff file and the captures, frame dumps and reference captures from that slice's own run; the branch brought current with the remote branch it lands on, by rebase or merge as the repo does it; the repo's checks, and its running-app proof where it has one; `review` on the whole branch by one fresh agent, briefed with the branch's diff and log in files named by absolute path, as for `design-review`, each finding it returns fixed in a commit of its own, whose one fresh re-review judges the fix against the finding, reads the branch's diff so its accept covers the branch, and is that commit's `design-review`; then land as the repo's rules say, stopping for the owner when the change meets a condition those rules set for the owner's approval, and naming it; once the branch has landed, wait for every CI run on the landed commit to finish, on GitHub through `gh run list --commit` with the landed commit's full sha, never a short one: after a fast-forward, `git rev-parse HEAD` once pushed, and after a merge or pull request, the merge commit's sha, such as `gh pr view <n> --json mergeCommit -q .mergeCommit.oid`; and with `--branch` naming the branch the work landed on, since a push of the same sha to another branch leaves runs that must not count; repeated until a run appears for each workflow in `.github/workflows` that the push triggers, and then `gh run watch` on each run, and fix a red run before the task reports, never calling it unrelated, in a commit of its own through this same Close, on a new topic branch if the old one is gone; once every run is green, remove its worktree: where the optional agent-worktree is installed, its `remove` settles the branch, deleting a landed one, local and remote, and keeping one only for the reason it prints as `branch <name> kept, <reason>`, so leave a kept branch as it is; without it, delete the branch on the remote if it remains, then the local branch if it remains.

## Routes

| Route | When | File |
|---|---|---|
| Feature | New or changed behavior | [references/feature.md](references/feature.md) |
| Bug fix | Behavior that differs from what it should be | [references/bug-fix.md](references/bug-fix.md) |
| Refactor | A change to structure that keeps behavior, a redesign, or a removal | [references/refactor.md](references/refactor.md) |
| Test | A change only to tests, or to the spec wording they prove | [references/test.md](references/test.md) |
| Review | Someone else's change, or a change that already landed | [references/review.md](references/review.md) |

## See also

- `design-review` — the judgment every route's commits wait on
- `ui-review` — the judgment a commit that changes an interface also waits on
- `coordinate` — run work across several agents or repos, each task delegated to this skill, and resume a coordinating session

## Red flags

- A code edit made outside a route
- Skipping a step because the change looks small
- The session that wrote a change running its `design-review` or `ui-review`
- A diff file another worker can overwrite
- Landing past a repo rule that asks the owner first
- A task reported as landed while a CI run on its landed commit is red or still running, or once a run from another branch passed in place of the landed one
- A return left partly fixed, or review stopped before an accept, except to park a commit after its third return: its diff saved, the commits that do not depend on it carried on, and it reported with what the three returns show and the one decision that would end them
- A finding on code the change touches left unfixed, or a follow-up written as a backlog line instead of a queued task
- Working around a defect in a tool, hook or gate instead of stopping and reporting it
- Picking up another session's work through this skill instead of `coordinate`'s resume
