---
name: doc-review
description: Review docs as prose for a reader, not as code — drift, shape and verbosity. Use when a change edits docs or changes behavior a doc describes.
---

# Documentation Review

Judge each doc the diff changes or makes stale the way a reader meets it: whether it is still true, easy to scan, and short.

## Scope

Report what the diff causes, such as a line it leaves as it was but makes wrong; place what it did not cause where the review report in `principles` puts it.

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
- one term used for two meanings, or two terms for one
- text that maps one set to another where a table would read faster

### 3. Brevity

Verbosity is a finding: a fact said twice, hedges, history, filler, or any word whose deletion loses nothing.

## Workflow

Read the diff, then each doc it changes or makes stale, whole. For changes touching many docs, fan out **fast-tier** readers, one per doc, to surface candidates. Verify each before reporting.

## Output

Report each finding as `principles`' review report says: **Where** is the file and line, **Why** what drifted, breaks the shape or can go, and **Instead** the fix, for brevity the shorter wording itself.

- Bad: "README could explain the retry architecture in more depth."
- Good: **Why:** `docs/config.md` still says `maxRetries` defaults to 3, and this diff changes it to 5 in `src/client.ts`.
- Good: **Why:** `README.md:12` says the cache "is designed to make sure that reads are generally fast"; **Instead:** "The cache serves repeated reads."

If nothing drifted, breaks the shape or can go, Findings is `none`.

## See also

- `docs-writing`, whose shape and brevity rules this review checks
- `review`, which runs this review when docs or the behavior they describe change
- `principles` for the review report shape a finding takes

## Red flags

- Rewording to taste that cuts nothing and breaks no rule above
- Judging a doc by code rules: types, patterns or smells
- Asking for more words where the doc already says the fact once
- Treating roadmap notes as shipped behavior
