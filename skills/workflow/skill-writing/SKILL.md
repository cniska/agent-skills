---
name: skill-writing
description: Create, fix or update a skill, matching the conventions of the set it belongs to. Use when authoring a new skill, amending an existing one, or checking whether a skill is needed or missing a rule.
---

# Skill writing

A skill is a self-contained instruction to a model — a directory holding a `SKILL.md`, the references it reads when a step needs them, and the scripts it names, each reached under that directory. This skill carries the *how* of writing one; the repo that holds the set owns its mechanical rules (frontmatter, required sections, links, its validator), usually in its `AGENTS.md`. Read those first; don't restate them in the skill.

Two modes, inferred from the request:

- **Create** — a capability has no skill yet. Clone the shape of the closest existing skill; the repo's validator catches what is missing.
- **Update** — a rule needs sharpening or cutting. Add one only when it holds in any project, two independent sessions saw its failure, and no existing line fits.

## Workflow

1. **Pick the mode** and read the repo's rules for authoring skills.
2. **Find the closest sibling** and match its shape — don't invent a new one. A skill that files something clones the nearest skill that files something; a review dimension clones another review dimension.
3. **Write to the conventions**: the body in `writing`'s medium for instructions an agent follows, imperative, terse, `description` starts with a verb and says when to use it; reference other skills by bare name, never by path; match the sibling's section order and lead-in style. Cut a how only where the model would do the same without it, such as a command walkthrough, a tool's mechanics or a step it takes unprompted. Keep a how it could not do as well unaided. Keep generic guidance that holds in any project, such as standards, catalogs, methods and judgment calls. Leave tools, their use and project specifics to repo rules and tool session notes; a skill holds in any repo. Write each rule to stand without its source, since an agent applies the rule and never opens the page behind it; the sources go in the commit or the report. When a skill or agent definition sets an output, what a tool or file receives is schema-checked data and only what a person reads is prose, in the form no text heuristics from `principles` gives each receiver.
4. **Sweep for drift**: apply no drift from `principles` to the skill's own description, any index or README that lists it, and sibling skills or hooks that restate or act on what changed, and, where the repo has a trigger check, that skill's trigger prompts ([evals](references/evals.md)).
5. **Validate** with the repo's validator. Reach for an eval ([evals](references/evals.md)) only when the change's risk needs one, such as a behavior the skill exists for or a past regression no cheaper check can judge; a model run needs the owner's approval, so name the run and why in the report instead of starting it.
6. **Commit** the way the repo's rules say, only once the user gives the go.
7. **Check it in real use** once it lands: `workflow-review` judges the skill as a whole after weeks of work.

## See also

- `principles` — no drift, for the description, index and siblings a change leaves stale, and no text heuristics, for an output a tool or file receives
- `writing` — how a skill's body is worded for the agent that follows it
- `search-sessions` — evidence that a friction repeats across sessions before adding guidance for it
- `workflow-review` — judges a skill whole over weeks of real use
