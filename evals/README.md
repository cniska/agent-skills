# Evals

Behavioral tests for the skills. `validate.sh` proves a skill is well-formed; this proves it **works** — that loading it steers an agent to the intended behavior, and that editing the prompt didn't regress it. Bash + `jq`, matching the rest of the repo; the only dependency beyond that is the `claude` CLI.

Dev-only. It makes real `claude -p` calls, so it is **not** a per-commit hook — run it before shipping a skill change, or nightly. It never ships: `npx skills add` copies only `<name>/`, so `evals/` at the repo root is invisible to installs.

## Run

```
make eval                          # all scenarios, treatment arm, gate on regression
make eval ARGS=--baseline          # also run the no-skill arm (discrimination check)
make eval ARGS="--skill=correctness-review --k=3"
make eval ARGS=--update-baseline   # rewrite baseline-results.json from this run
make rules                         # which rules have an assertion behind them (free)
make test                          # run the harness's own unit tests (offline, no API)
```

Before spending anything it prints the estimated number of `claude -p` calls and waits for a `y`. Pass `--yes`/`-y` to skip the prompt in CI; it refuses to run non-interactively without `--yes`, so it can't burn tokens by accident.

## Why it's shaped this way

Three findings from the pilot that authored the first scenario (2026-07-10, `claude-opus-4-8`) drive the design:

- **The baseline arm is not optional.** A frontier model finds a planted bug **with no skill loaded at all** — so "found the bug" tests the model, not the skill. Every scenario lists `baseline_must_fail`: assertions the no-skill arm must fail. If it passes them, the assertion is non-discriminative and proves nothing. For `boundary-discount`, at k=5:

  | Assertion | skill | no-skill baseline |
  |---|---|---|
  | found the bug | 5/5 | 5/5 — not discriminative |
  | `severity-label` | 5/5 | 0/5 |
  | `contract-shape` | 5/5 | 0/5 |

  The skill's value is the **contract** (the canonical severity vocabulary and finding shape the `review` orchestrator aggregates), not the bug-finding. Run `--baseline` when authoring a scenario to confirm discrimination.

- **Grade cheapest-first.** Deterministic `grep -E` checks run first (free, no LLM) — most regressions live here because the skills mandate *structure*, and structure is grep-able. The LLM judge handles only the paraphrase-tolerant residue. In the pilot the deterministic layer graded every discriminative assertion on its own.

- **Trust the judge narrowly.** It's blinded (sees one assertion + the output, not the skill or the expected verdict), returns a structured verdict, and a `pass` whose evidence isn't a verbatim substring of the transcript is rejected — the cheapest guard against hallucinated evidence.

Transcripts are nondeterministic, so each scenario runs `k` times (default 5) and findings are pass *rates*, gated against `baseline-results.json`; a drop is a regression (non-zero exit).

## Does a rule earn its place?

A skill's rules cost context on every load and narrow the model's own judgment, so each one has to be doing work. Two instruments answer that, one free and one not.

**`make rules`** is the free one. It lists every rule-shaped line in every skill — body prose and list items, which is everything that instructs — and marks each `claimed` or `untested`. A rule is claimed when some scenario assertion names it, through the `det_rule`/`sem_rule` arrays that run parallel to `det_id`/`sem_id`. An address is a substring matching **exactly one** rule-shaped line; zero means the rule was reworded and the assertion now proves nothing, several means the assertion can't say which rule it proves, and both fail the run. `make rules ARGS=--skill=<name>` lists that skill's lines individually.

Untested is the honest default and most rules will sit there for a long time. The report's value is knowing which ones do not.

**`make eval ARGS="--skill=<name> --ablate=<address>"`** is the one that spends tokens. It runs three arms that differ only in the skill text — full, full minus that one rule, and none — and prints each assertion's pass rate across them. All three disable the installed skill and inject the text through `--append-system-prompt-file`, so an arm cannot differ by *how* the skill was invoked. Harm needs no special machinery: an assertion the trimmed arm passes more often than the full arm says the rule made the output worse.

A gap narrower than the threshold is two runs flipping, not a finding. Ablation never touches `baseline-results.json` — those numbers come from the installed skill, which is a different delivery path and not comparable.

Most cuts don't need this. Reading finds duplicated rules, contradictions and numbers a file argues against itself; dry-running a changed skill on unlike repos (the `skill-test` skill) finds guidance that fights reality. Reach for ablation when a rule is the sole carrier of a contract assertion, or when you suspect it makes output worse rather than merely doing nothing.

## Adding a scenario

`evals/<skill>/<name>.sh` sets, for the runner to source: `skill`, `invoke`, `task`, `fixture` (a path, staged into the prompt so the agent never sees the scenario spec — keep names neutral so they don't leak the answer), `k`, parallel `det_id/det_re/det_expect` (regex checks), parallel `sem_id/sem_assertion/sem_expect` (judge assertions), `baseline_must_fail`, and `det_rule/sem_rule` naming the rule each assertion proves. See `correctness-review/boundary-discount.sh`. Aim for 5–8 scenarios per skill including a clean-input negative and a style-bait negative; assert *behaviors*, never skill *phrasings*.

**Next skill to add: `handoff`.** Much of its contract is deterministic (section names and order, one line per bullet, the closing imperative, no report-shape headings). Length is not: the skill states it as "fits on one screen" rather than a word count, so that assertion belongs to the judge. One catch: its fixture is a session transcript (the priciest kind). The workflow is headless-friendly — no confirmation gate, and the handoff is always printed in the reply, so assert against that.
