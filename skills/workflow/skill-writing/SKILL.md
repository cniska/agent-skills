---
name: skill-writing
description: Write, fix or cut a skill or agent definition so it stays short, says what to do and is found by its description, and decide where a rule belongs. Use when adding a skill, fixing or amending one, or checking whether a skill is needed or missing a rule.
---

# Skill writing

A skill is an instruction a model loads when its description matches the work: a directory holding a `SKILL.md`, the references it reads when a step needs them, and the scripts it names. Write one so the agent that loads it does the work the owner's way and reads nothing it does not need. The repo that holds the set owns its mechanical rules and the checks that enforce them; read those first.

## What matters

- **Write for where it loads.** Most skills load at a step of a workflow that has already set up the branch, the reviews and the repo's rules. Write the body for that case and lean on what the workflow provides, while the skill still works loaded alone.
- **Keep the body short where it loads often.** Every line costs on every load, so a body holds only what every run needs. Move guidance a run needs only sometimes into a reference file, and name that file at the point it applies.
- **The description finds the skill.** A model picks a skill from its description alone, so say what the skill does and when to use it, specifically enough to pick it from the set. Leave out keyword lists aimed at typed prompts. Where the repo has trigger checks, change the skill's trigger prompts with its description ([evals](references/evals.md)).
- **Write the body as `writing` says for instructions an agent follows.**
- **Name another skill by its bare name, only at a step that runs it.** Otherwise the model finds it by its description.
- **Write a purpose, then what matters, then any hard limits.** Give a point its reason where the reason is not obvious, since an agent applies a rule better when it knows what the rule protects. A skill that shares a shape with siblings, such as another review area, matches their sections.
- **Say what to do.** Keep a ban on a concrete thing only where past sessions show agents doing that thing without it, and word it as what to do instead. A principle known by its negative, such as no comments, keeps its name, and its rule line still says what to do.
- **Keep what the model could not do as well unaided**: the standards, catalogs, methods and judgment calls that hold in any project. Cut a how it would follow without being told, such as a command walkthrough or a tool's mechanics.
- **Leave tools to the repo.** Tools, their use and project specifics belong to the repo's rules and each tool's session note, so the skill holds in any repo. A skill whose subject is a tool, or choosing one, names it.
- **Write each rule to stand without its source**, since an agent applies the rule and never opens the page behind it. The sources go in the commit or the report.
- **Make what a tool or file receives schema-checked data.** Only what a person reads is prose, in the form no text heuristics in `principles` gives each receiver.
- **Find what depends on a line before cutting or moving it,** and move a behavior that line alone carries to where its dependents still reach it.
- **Cut before adding.** Add a rule only when it holds in any project, two independent sessions show the failure, and no line covers it. Run `search-sessions` for those two sessions. A rule a tool can check becomes a check.
- **Sweep for drift** as no drift in `principles` says: the description, any index that lists the skill, and the siblings, hooks and schemas that cite its name, headings or anchors or restate what changed. Keep established names.

## Where a rule belongs

Each kind of content has one home, and a skill holds only the first.

| Content | Home |
|---|---|
| How-to that holds in any project | A skill |
| A repo's conventions and commands, short and mostly pointers | Its rules file (`AGENTS.md`) |
| Observable behavior | `SPEC.md` |
| How it works and how to use it | Docs |
| Why a decision was made | An ADR or the docs, as the project keeps them |
| What changed, in short | The commit subject |
| Anything a tool can enforce | A check |

## Limits

- Write an eval ([evals](references/evals.md)) only when the change's risk needs one, such as a behavior the skill exists for or a past regression no cheaper check can judge.
- A model run needs the owner's approval: name the run and why in the report instead of starting it.
