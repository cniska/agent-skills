---
name: docs-writing
description: Create or update project documentation in the house style of the docs beside it, each claim checked at its source and each fact in the doc that owns it. Use before the first edit to a README, architecture, runtime, reference or design doc, or when a behavior change leaves docs to update.
---

# Docs writing

A doc explains what the system does now, for agents and developers who read it once and then come back to it as a reference. Each doc has one owner, one H1 and one job. Write it as `writing` says for documents that last.

## What matters

- **Put each fact in the doc that owns it.** The repo's doc map decides which doc that is, wherever the repo keeps the map: a docs index, the spec or the rules file. Every other doc links to the owner, since a fact kept in two places drifts. Where the repo has no map, the doc that already holds the fact owns it.
- **Match the docs beside it.** Give each page the structure, vocabulary and voice of its neighbors. Where the repo's docs set no formatting of their own, use one H1 naming the topic in title case, H2 and below in sentence case, and bullets that start with a bold label or a capital letter.
- **Open with the summary.** The first sentence says in one line what the doc covers, so the reader knows without scrolling.
- **Use the business term** where it differs from the technical one, since that is the word the reader brings.
- **Draw a chart** as [diagrams](references/diagrams.md) says: when it beats prose or a table, which chart fits the question, and the check that renders it.

## Shape

A reader scans a doc before reading it, so text walls and long bullets hide its facts. These hold in every repo, over a neighbor that breaks them.

- One heading per subject.
- A paragraph holds about four sentences at most.
- A list holds two items or more; a single item is a sentence.
- A bullet runs about two lines at most; a longer one becomes a paragraph or its own subsection.
- A procedural sentence holds one instruction in about 20 words at most; a descriptive one, about 25.
- A noun cluster holds three words at most; a longer one takes a verb or a preposition.
- One term per meaning, and one meaning per term.
- A note gives information, and each instruction goes in the step it governs.
- A table maps one set to another, such as options to defaults or commands to effects; reasons and explanations stay prose.

## Workflow

1. **Read the code.** The doc describes what the code does now. Read the source files, contracts and tests before writing anything, and for a change, the code that changed.
2. **Read the doc map and the docs beside it.** Find the doc the map says owns each fact, and read an existing doc whole before changing it.
3. **Write it in its home.** In an existing doc, merge into the owning section: rewrite a bullet that overlaps, and give a new concept its own subsection. A subject with no home yet gets a new doc, shaped as [a new doc](references/new-doc.md) says.
4. **Sweep every mention.** For each changed behavior, search the README, the docs folder, the spec and the rules file for its name, command and flags, and for each passage that acts on it in other words. Fix each hit, as no drift in `principles` says, and turn a mention outside the owning doc into a link to it.
5. **Update the docs index** when a doc is added or its scope changes.
6. **Check each claim at its source.** For every claim the doc adds or alters, read the file and line it rests on, such as the script, config or test, or run the command it describes, and apply verify at the source from `principles`. When the code and the doc disagree, the code wins.
7. **Hand the sources to the reviewer.** List each changed claim with the file and line it rests on, and put that list in the review brief, so the reviewer reads the source rather than taking the doc's word.
