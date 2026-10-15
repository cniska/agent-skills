# Skill evals

An eval measures what a skill changes. Each case runs the agent in a small, realistic situation and checks what it did. Every comparison is a champion against a challenger on the same cases: the skill as committed against your uncommitted edit, `main`'s skills against another ref's, or the skills against the set with one skill removed, which shows whether a case measures it. Only the cases are committed; a challenger is a working-tree edit, tried and then kept or discarded.

How to find a behavior worth a case, write graders that can fail, and score a change is in [the `skill-writing` eval reference](../skills/workflow/skill-writing/references/evals.md).

Runs use Claude Code's [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals). Each run loads this repo's plugin from a scratch copy, with its skills, hooks and agents, and starts in a clean setup with nothing else loaded. A case declares the skills it exercises as an inline `tags` list in its `prompt.md` frontmatter (`tags: [git]`), and `--skill` runs only the cases tagged with that skill.

## A case

```text
evals/scenarios/<case>/
├── prompt.md        # what a user would type, never naming the skill; tags, run limits and tools in frontmatter
├── case.yaml        # points at the scaffold
├── scaffold.sh      # builds the throwaway workspace the run starts in
├── graders/         # one pass/fail check per file, read from the trace, the final message or a file
└── traces/          # saved runs, and expected.json: the verdict each grader must give each one
```

A run's score is the share of its graders that passed. Each case runs several times per side, because the model answers differently each time.

## Commands

Evals call the model as you and count against your usage: run them locally, never in CI.

```bash
mise run eval                                       # every case against this tree's skills
mise run eval --skill git                           # only the cases tagged git
mise run eval --skill git --against HEAD --runs 5   # champion (last commit) against challenger (your edit)
mise run eval --against origin/main --runs 5        # main's skills against this tree's
mise run eval --skill git --against none            # does each case measure the skill? (skill removed)
mise run eval:summary [<base.json>] [<head.json>]   # reprint the newest run's summary, or the given results
mise run test:evals                                 # every grader against its saved traces, no model (CI runs this)
mise run test:triggers                              # skill descriptions against trigger prompts, no model (CI runs this)
mise run eval:prove <case-dir> [--workspace <dir>] <trace>...   # grade any trace ad hoc
mise run eval:keep <head.json> <case> <run> <label>   # save a kept run's trace into the case
```

To improve a skill: edit it, run `mise run eval --skill <name> --against HEAD --runs 5`, and read the two rows per case: base is the committed champion, head your challenger. If the head holds or beats the base across the runs, commit it and it becomes the champion; if it drops, `git restore` it. Repeat until every case scores where you want it.

## Reading the summary

```text
git-sync-branch
  base with   33%  [33 33 33 33 33]  failed: no-merge×5, rebased×5, skill-fired×5
  head with  100%  [100 100 100 100 100]
```

Each row is one side: the mean score, each run's score, and the graders that failed with how many runs failed them. This one is `--against none`: without the skill the agent merges, with it it rebases, so the case measures the skill. A case where both sides pass measures nothing. Every grader counts, including whether the skill fired.

## Triggering

`evals/triggers/<skill>.json` lists prompts that should load the skill, and prompts that belong to another skill with that skill named as the owner:

```json
{
  "positive": [{ "prompt": "rebase my branch on main" }],
  "negative": [{ "prompt": "open a pull request", "owner": "pr" }]
}
```

`mise run test:triggers` scores every prompt against every skill description by word similarity, with no model, and reports each skill's first-place rate, the prompts it loses and to which skill, and descriptions so alike a model could not tell them apart. It fails when a positive prompt loses first place, when a skill comes first for a prompt that belongs to another, and when two descriptions are 50% alike or more, a limit set well above the closest pair when it was introduced. Word similarity is only a proxy for how a model picks a skill: a lost prompt fails the run until the description of the skill it should load is reworded, and a triggering case run by the model settles which wording a model picks.

## Saved traces

`claude plugin eval` has no offline mode, so a grader is proven on saved traces before a paid run counts. `traces/expected.json` maps each saved trace to the verdict each grader must give it:

```json
{ "<trace>.jsonl": { "workspace": "<dir, optional>", "expect": { "<grader>": "pass" } } }
```

`mise run test:evals` fails if any grader disagrees, or is never seen both passing and failing. It parses every grader when it loads, refusing an unknown type, an unknown option on `regex`, `tool_used` and `tool_order`, and a pattern that does not compile; it also refuses an expectation naming no grader, or one the trace cannot check. It checks `regex`, `tool_used` and `tool_order` graders. What a trace cannot show is left to the model run: `llm`, `baseline` and `file_exists` graders, a `regex` on `files` or `mock_calls`, and a file grader with no workspace or a missing file. Run with `--keep-temp` to keep a run's traces, then save one with `eval:keep` before the temporary directory is cleaned; hand-written traces cover the bad cases real runs never produce. A grader that reads a file gets a small workspace folder under `traces/`, named in `expected.json`.

## The sandbox

Runs are sandboxed: no network, git hooks do not run, and on macOS Apple's `/usr/bin/git` fails to write its cache. Cases that use git carry a one-line machine note in `append_system_prompt` naming a git that works; scaffolds run tests with the test runner itself, not through a package manager script that reaches a registry.
