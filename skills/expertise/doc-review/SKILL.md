---
name: doc-review
description: Review docs as prose for a reader, not as code — drift, shape, verbosity and a whole page's structure. Use when a change edits docs or changes behavior a doc describes, or when a readme or page is hard to read, such as a wall of text or missing headings.
---

# Documentation Review

Judge each doc the way a reader meets it: whether it is still true, easy to scan, and short.

A diff gets the review below. A whole doc, meaning its purpose, its outline and a restructure, gets [the whole-doc review](references/whole-doc.md). [The patterns](references/patterns.md) name the shapes a doc falls into and the form each should take instead; a finding cites one by name as its **Rule**.

## Scope

### 1. Drift

- a behavior, contract, default or name the diff changed that a doc still states the old way
- a new term missing from the glossary where the repo keeps one
- a fact repeated in a second doc where a link to its owner would do
- implementation detail where the concept is enough, or roadmap written as shipped

### 2. Shape

- a list with one item
- a bullet longer than about two lines
- a paragraph longer than about four sentences, or a subject with no heading of its own
- a procedural sentence over about 20 words or carrying two instructions; a descriptive one over about 25
- a noun cluster of four words or more
- one term used for two meanings, or two terms for one
- a note that tells the reader to act, where it should only inform
- text that maps one set to another where a table would read faster

### 3. Brevity

Verbosity is a finding: a fact said twice, hedges, history, filler, or any word whose deletion loses nothing.

## Evidence threshold

Report what the diff causes, such as a line it leaves as it was but makes wrong. Place what it did not cause where the review report in `principles` puts it.

- **A diff that adds to a section that already breaks the shape** grew it, so that section's structure is the change's finding, and its **Instead** restructures the section.
- **A doc's structure that was wrong before the diff**, such as a wall, a subject with no heading or a mapping written as prose, hides facts from every reader, so it is a real defect, not a style point. Report it as a follow-up for a whole-doc review of that doc. A single long sentence or bullet left as it was is a style point, and dropped. A list whose bullets run long, as in the long bullets pattern, is structure and goes to that follow-up.

## Workflow

Read the diff, then each doc it changes or makes stale, whole. When it touches more docs than one read can cover, a fast-tier reader per doc can surface candidates; verify each before reporting.

## Output

Report each finding as `principles`' review report says: **Where** is the file and line, **Why** what drifted, breaks the shape or can go, in one sentence about this doc, and **Instead** the fix written out: the shorter wording, the new headings, or the table with its rows. Word each finding as a plain statement.

- Bad: "README could explain the retry architecture in more depth."
- Bad: "The setup section might benefit from some restructuring."
- Good: **Why:** `docs/config.md` still says `maxRetries` defaults to 3, and this diff changes it to 5 in `src/client.ts`.
- Good: **Why:** `README.md:12` says the cache "is designed to make sure that reads are generally fast"; **Instead:** "The cache serves repeated reads."

If nothing drifted, breaks the shape or can go, there is no finding.
