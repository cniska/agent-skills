---
name: docs-writing
description: Create or update project documentation in the house style of the docs beside it, each claim checked at its source and each fact in the doc that owns it. Use before the first edit to a README, architecture, runtime, reference or design doc, or when a behavior change leaves docs to update.
---

# Docs writing

A doc explains what the system does. One owner, one H1, one job. Written for agents and developers to read once and reference forever.

## Conventions this skill enforces

- Apply `writing`'s rules for documents that last: each fact once, in the fewest words that keep its meaning, within the page as across docs; current state only; no volatile numbers; each page in the structure, depth and voice of its neighbors. The formatting conventions and the template below hold only where the repo's docs set none of their own; the shape rules hold in every repo, over a neighbor that breaks them.
- The repo's own doc map decides which doc owns a fact, wherever the repo keeps it: a docs index, the spec or the agent rules file. The fact lives in that doc, and every other doc links to it. Set no split between the README, the docs and the spec of your own; where the repo has no map, the doc that already holds the fact owns it.
- One H1 per doc. H1 is the topic in title case. H2+ are sentence case.
- First sentence is the summary. One line. The reader knows what this doc covers without scrolling.
- A chart follows [diagrams](references/diagrams.md): when it beats prose or a table, which Mermaid chart fits the question, and the check that renders it.
- Bullets start with a bold label or a capital letter.
- Business terminology wins over technical terms when they differ.
- No marketing language. State what it does.
- No speculative future work. If it's not shipped or actively being built, it doesn't belong.

## Shape

A reader scans a doc before reading it, so text walls and long bullets hide its facts.

- One heading per subject.
- A paragraph holds about four sentences at most.
- A list holds two items or more; a single item is a sentence.
- A bullet runs about two lines at most; a longer one becomes a paragraph or its own subsection.
- A procedural sentence holds one instruction in about 20 words at most; a descriptive one, about 25.
- A noun cluster holds three words at most; a longer one takes a verb or a preposition.
- One term per meaning, and one meaning per term.
- A note gives information, never an instruction; the instruction goes in the step it governs.
- A table where text maps one set to another, such as options to defaults or commands to effects; never a table for prose.

## Template

```
# [Topic]

One-sentence summary of what this doc covers.

## [Primary content]

Tables, charts, and bullets.

## Design rule

One paragraph. What principle explains why this design is the way it is?
```

Omit sections that don't apply. Cross-reference related docs where they own adjacent context.

## Workflow

1. **Read the code.** The doc describes what the code does now, not what you think it should do. Read the source files, contracts and tests before writing anything, and for a change, the code that changed.
2. **Read the doc map and the docs beside it.** Put each fact in the doc the map says owns it, and match the neighbors' structure, vocabulary and voice. Read an existing doc whole before changing it.
3. **Write it in its home.** In an existing doc, find the owning section and merge, don't append: rewrite a bullet that overlaps, and give a new concept its own subsection. A subject with no documentation home yet gets a new doc of the type below that fits it, in the structure the docs of that type share, or the template where they share none, cross-referencing docs that own adjacent context.
4. **Sweep every mention.** For each changed behavior, search the README, the docs folder, the spec and the agent rules file for its name, command and flags and for each passage that acts on it in other words, and fix each hit, as no drift in `principles` says; a mention outside the owning doc becomes a link to it.
5. **Update the docs index** (e.g. `docs/README.md`) when a doc is added or its scope changed.
6. **Check each claim at its source.** For every claim the doc adds or alters, read the file and line it rests on, such as the script, config or test, or run the command it describes, and apply verify at the source from `principles`. If the code and doc disagree, the code wins.
7. **Hand the sources to the reviewer.** List each changed claim with the file and line it rests on, and put that list in the review brief, so the reviewer reads the source rather than the doc's word for it.

## Doc types

- **Architecture** — system layout, trust boundaries, data flows, request paths.
- **Design** — schema, column definitions, indexes, constraints, transactional functions.
- **Security** — threat model, severity matrices, build invariants.
- **Runtime** — behavior during a request. Lifecycle, tool execution, memory.
- **Reference** — tables and lists. CLI commands, configuration options, error codes.
- **Comparison** — feature matrices, benchmark results.
