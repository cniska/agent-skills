---
name: doc-review
description: Review docs for drift, missing updates, and terminology changes. Use when code changes should be reflected in documentation.
---

# Documentation Review

Review the docs the diff affects for drift — terms, contracts, and behavior the change made stale.

## Scope

Report the drift the diff causes, such as a doc line it leaves as it was but makes wrong, and place drift the change did not cause where the review report in `principles` puts it.

- canonical doc updates for behavior, contract, or config changes
- glossary drift when new terms are introduced
- duplicated concepts introduced or worsened by this change
- outdated names or contracts after refactors
- new or changed docs staying conceptual rather than describing implementation

## Workflow

Read the diff, then the affected doc files. For changes touching many docs, fan out **fast-tier** readers — one per doc — to surface drift candidates. Verify each before reporting.

## Output

Report each drift as `principles`' review report says: **Where** is the affected file, **Why** what drifted or is missing, and **Instead** the fix direction.

- Bad: "README could explain the retry architecture in more depth."
- Good: **Why:** `docs/config.md` still says `maxRetries` defaults to 3, and this diff changes it to 5 in `src/client.ts`.

If nothing drifted, Findings is `none`.

## See also

- `review`, which runs this review when docs or the behavior they describe change
- `pr` for change summaries and issue linkage
- `principles` for the review report shape a drift takes

## Red flags

- Generic prose polishing
- Duplicate explanations across docs
- Implementation detail where a concept is enough
- Treating roadmap notes as shipped behavior
