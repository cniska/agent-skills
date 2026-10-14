---
name: skill-writing
description: Create, fix or update a skill, matching the conventions of the set it belongs to, and dry-run it on unlike real repos. Use when authoring a new skill, amending an existing one, or testing a changed skill before pushing it.
---

# Skill writing

A skill is a self-contained instruction to a model — a directory holding a `SKILL.md` and any references it loads on demand. This skill carries the *how* of writing one; the repo that holds the set owns its mechanical rules (frontmatter, required sections, links, its scaffold and validator), usually in its `AGENTS.md`. Read those first; don't restate them in the skill.

Two modes, inferred from the request:

- **Create** — a capability has no skill yet. Start from scaffolding, then clone the shape of the closest existing skill.
- **Update** — a skill exists and a rule needs adding or sharpening. Merge into the right section and trim what it duplicates; never blind-append. Updating is the harder half.

## Workflow

1. **Pick the mode** and read the repo's rules for authoring skills.
2. **Find the closest sibling** and match its shape — don't invent a new one. A skill that files something clones the nearest skill that files something; a review dimension clones another review dimension.
3. **Scaffold (Create only)** with the repo's scaffold command or template, where it has one.
4. **Write to the conventions**: imperative body, terse, `description` starts with a verb and says when to use it; reference other skills by bare name, never by path; match the sibling's section order and lead-in style. Keep only what changes what the model does: for each line, ask whether the model would act differently without it, and cut what it already knows, such as a standard catalog or a textbook method. Keep project specifics out: a skill states what holds in any repo and defers the rest to the repo's own rules.
5. **Sweep for drift**: apply no drift from `principles` to the skill's own description, any index or README that lists it, and sibling skills or hooks that restate what changed, and, where the repo has a trigger check, that skill's trigger prompts ([evals](references/evals.md)).
6. **Validate** with the repo's validator.
7. **Dry-run before pushing**: for any material change, read and run [the dry run](references/dry-run.md) on unlike real repos, and fold convergent fixes back in. A change is material if it alters what the skill detects, flags, or produces — even one bullet — not if it merely reads that way; a wording-only fix with no behavioral change (typo, link, terminology) can skip the dry-run.
8. **Score on evals**, where the repo has cases for the skill: the committed skill as champion against the change as challenger, and a new case when the change adds a rule a model breaks without the skill. Read [evals](references/evals.md).
9. **Commit** the way the repo's rules say, only once the user gives the go.

## See also

- `principles` — no drift, for the description, index and siblings a change leaves stale
- `search-sessions` — evidence that a friction repeats across sessions before adding guidance for it

## Red flags

- Restating the repo's mechanical rules in the skill body, so the two drift
- A project's commands, paths, branches or names written into a skill
- Inventing a new structure instead of cloning the closest sibling
- Blind-appending a rule on update instead of merging and trimming duplicates
- Pushing a materially changed skill without the dry run, or because it reads well
- Treating a small diff as automatically non-material — a single new bullet can change what a skill flags
- Dry-run repos that rhyme — same stack, same shape, same conventions
- A dry-run prompt that says it is a test or names the skill to load
- Grading a run from what the runner reports rather than from the files its log shows it opened
- Judging the new version with no baseline, or under labels that say which version is new
- A dry run in a checkout that can push, an output landed from it, or the version under test installed where other sessions read skills
- Growing a skill with rules for one-off friction instead of trimming, or leaving friction that converged across repos unfixed
- Restating what the model already knows, such as a smell catalog or a well-known method, where it would act the same without it
- Referencing another skill by path instead of bare name
