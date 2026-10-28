---
name: skill-writing
description: Create, fix or update a skill, matching the conventions of the set it belongs to. Use when authoring a new skill, amending an existing one, or checking whether a skill is needed or missing a rule.
---

# Skill writing

A skill is a self-contained instruction to a model — a directory holding a `SKILL.md`, the references it reads when a step needs them, and the scripts it names, each reached under that directory. This skill carries the *how* of writing one; the repo that holds the set owns its mechanical rules (frontmatter, required sections, links, its validator), usually in its `AGENTS.md`. Read those first; don't restate them in the skill.

Two modes, inferred from the request:

- **Create** — a capability has no skill yet. Clone the shape of the closest existing skill; the repo's validator catches what is missing.
- **Update** — a skill exists and a rule needs adding or sharpening. Merge into the right section and trim what it duplicates; never blind-append. Updating is the harder half.

## Workflow

1. **Pick the mode** and read the repo's rules for authoring skills.
2. **Find the closest sibling** and match its shape — don't invent a new one. A skill that files something clones the nearest skill that files something; a review dimension clones another review dimension.
3. **Write to the conventions**: imperative body, terse, `description` starts with a verb and says when to use it; reference other skills by bare name, never by path; match the sibling's section order and lead-in style. Keep only what changes what the model does: for each line, ask whether the model would act differently without it, and cut what it already knows, such as a standard catalog or a textbook method. Keep project specifics out: a skill states what holds in any repo and defers the rest to the repo's own rules. Write each rule to stand without its source, since an agent applies the rule and never opens the page behind it; the sources go in the commit or the report.
4. **Sweep for drift**: apply no drift from `principles` to the skill's own description, any index or README that lists it, and sibling skills or hooks that restate or act on what changed, and, where the repo has a trigger check, that skill's trigger prompts ([evals](references/evals.md)).
5. **Validate** with the repo's validator. Reach for an eval ([evals](references/evals.md)) only when the change's risk needs one, such as a behavior the skill exists for or a past regression no cheaper check can judge; a model run needs the owner's approval, so name the run and why in the report instead of starting it.
6. **Commit** the way the repo's rules say, only once the user gives the go.
7. **Check it in real use** once it lands, where the host has the signals: the session record's skill loads by version, and the friction the change aimed at. `workflow-review` compares them before and after it landed, over the following days.

## See also

- `principles` — no drift, for the description, index and siblings a change leaves stale
- `search-sessions` — evidence that a friction repeats across sessions before adding guidance for it
- `workflow-review` — keeps or reverts a recent change by its real-use signals

## Red flags

- Restating the repo's mechanical rules in the skill body, so the two drift
- A project's commands, paths, branches or names written into a skill
- Inventing a new structure instead of cloning the closest sibling
- Blind-appending a rule on update instead of merging and trimming duplicates
- Starting a model eval run the owner did not approve
- Growing a skill with rules for one-off friction instead of trimming, or leaving friction that repeats in real use unfixed
- Restating what the model already knows, such as a smell catalog or a well-known method, where it would act the same without it
- Referencing another skill by path instead of bare name
