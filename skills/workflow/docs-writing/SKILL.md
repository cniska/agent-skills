---
name: docs-writing
description: Create or update project documentation in the house style of the docs beside it, each claim checked at its source and each fact in the doc that owns it. Use before the first edit to a README, architecture, runtime, reference or design doc, or when a behavior change leaves docs to update.
---

# Docs writing

A doc explains what the system does. One owner, one H1, one job. Written for agents and developers to read once and reference forever.

Two modes, inferred from the request:

- **New** — create a doc for a system, subsystem, or concept that has no documentation home yet.
- **Edit** — update an existing doc to reflect a change in behavior, contract, or scope.

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
- A procedural sentence holds one instruction in about 20 words at most; a descriptive one, about 25 (ASD-STE100).
- One term per meaning, and one meaning per term.
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

### New mode

1. **Read the code.** The doc describes what the code does, not what you think it should do. Read source files, contracts, and tests before writing anything.
2. **Read adjacent docs and the doc map.** Understand what's already documented, match the adjacent docs' structure and voice, and put each fact in the doc the map says owns it.
3. **Determine the doc type.** Architecture, design, security, runtime, reference, or comparison — different types emphasize different sections.
4. **Fill the structure the adjacent docs of this type share**, or the template where they share none, cross-referencing docs that own adjacent context.
5. **Add to the docs index.** (e.g. `docs/README.md`)
6. **Verify.** Read the doc against the code, and apply verify at the source from `principles`.

### Edit mode

1. **Read the current doc.** Understand its structure and conventions before changing anything.
2. **Read the code that changed.** The doc must reflect what the code does now.
3. **Find the owning section.** The doc map names the doc; match its existing vocabulary and structure.
4. **Merge, don't append.** If an existing bullet overlaps, rewrite it. If a new concept is introduced, give it its own subsection.
5. **Sweep every mention.** For each changed behavior, search the README, the docs folder, the spec and the agent rules file for its name, command and flags and for each passage that acts on it in other words, and fix each hit, as no drift in `principles` says; a mention outside the owning doc becomes a link to it.
6. **Update the docs index.** If the doc's scope changed.
7. **Check each claim at its source.** For every claim the change adds or alters, read the file and line it rests on, such as the script, config or test, or run the command it describes, and apply verify at the source from `principles`. If the code and doc disagree, the code wins.
8. **Hand the sources to the reviewer.** List each changed claim with the file and line it rests on, and put that list in the review brief, so the reviewer reads the source rather than the doc's word for it.

## Doc types

- **Architecture** — system layout, trust boundaries, data flows, request paths.
- **Design** — schema, column definitions, indexes, constraints, transactional functions.
- **Security** — threat model, severity matrices, build invariants.
- **Runtime** — behavior during a request. Lifecycle, tool execution, memory.
- **Reference** — tables and lists. CLI commands, configuration options, error codes.
- **Comparison** — feature matrices, benchmark results.

## See also

- `writing` — the prose rules every lasting doc follows: one place per fact, current state only, no volatile numbers
- `principles` — verify at the source, for every claim a doc makes, and no drift
- `doc-review` — check docs for drift, shape and verbosity, and a whole doc's structure
- `spec` — requirements that docs reference
- `agents-md` — project rules that docs must follow

## Red flags

- Writing a doc without reading the code first
- A changed claim committed without its source read, or a review brief that leaves out where each claim rests
- A behavior change that fixes the doc it was asked about and leaves its other mentions stale
- A fact restated in a second doc instead of linked from the doc that owns it
- Creating a new doc when an existing one should be edited
- Adding speculative "future work" sections
- Writing prose where a table or chart would be clearer, as [diagrams](references/diagrams.md) judges it
- Omitting cross-references to adjacent docs
- A doc that says what something should do instead of what it does
