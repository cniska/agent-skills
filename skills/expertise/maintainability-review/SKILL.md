---
name: maintainability-review
description: Review whether changed code follows the codebase's own conventions for naming, layout and patterns and stays easy to read and change, citing the nearby code that sets each convention. Use when a diff changes code.
---

# Maintainability Review

Review whether changed code is easy to understand, change and extend, measured against the conventions the codebase already keeps. Rules that hold whatever the local convention, such as control flow, constants, indirection and comments, are `code-writing`'s and `design-review`'s.

## Scope

### 1. Naming and organization

- names consistent across types, constants, functions and files
- a name that describes its content, not its category, judged in context: a bare `data`, `temp` or `result` holding something specific is the smell, but the same word is right as the domain's own term, a published API name, or an accumulator the function builds and returns, so check the spec and the exports before flagging it
- a renamed concept kept aligned across code, tests, docs and exported identifiers
- constructors and factories named by one project convention
- modules and files laid out in the established project structure
- imports and exports following one pattern across the codebase

### 2. Control flow and state modeling

- assertions and errors following one pattern
- a data-driven lookup in place of a long control-flow chain, a predicate re-tested throughout a body, or a dispatch whose arms share an implementation. An exhaustive match over a closed type stays, since a lookup table there trades a compile-time guarantee for a runtime one.
- one error boundary per failure mode: nested or back-to-back `try` blocks mean the boundary is undecided, so each fallible step becomes a function that handles or propagates its failure

### 3. Pattern consistency

Where the codebase already has a clear local pattern:

- a structural pattern, such as table-driven or rule-driven, that nearby code uses
- errors classified by the project's established convention
- a repeated group of arguments that wants one named type
- sibling concepts with different intent kept apart, each with its own shape and name

### 4. Readability and changeability

- a comment the project's comment rule does not allow
- unused parameters, dead branches and ad-hoc fallbacks
- a new suppression of a type, lint or security check, in config or an attribute, or a stub standing where the work should be, such as an unimplemented throw or an empty catch turning a failure into silence. A suppression is a finding unless no rewrite meets the check without making the code worse and its reason is recorded where the project documents its lint, or in the attribute. A stub is a finding unless the diff says why.
- structure and terminology aligned with nearby code
- clear, idiomatic code over clever code

## Evidence threshold

Sections 1 and 3 need evidence of a local convention: cite the nearby code that establishes it. Sections 2 and 4 apply without repo evidence and rate **minor**, unless a documented convention raises them. A suppression comment rates **major**, since the comment rule refuses it.

## Workflow

1. Find the local conventions in the code near the change.
2. Compare them with the conventions the repo documents.
3. Find each concrete deviation and the evidence for it.
4. Report each deviation with its evidence.

## Output

Use the review report in `principles`. For each departure from convention, **Rule** names the convention, **Why** cites both the offending line and the code that establishes the convention, and **Instead** gives the fix direction.

- Bad: "`getUserData` — inconsistent, should be `fetchUserData`." (no evidence)
- Good: **Why:** `src/api/user.ts:12` `getUserData` breaks the fetch-prefix convention (9 of 10 siblings in `src/api/` use `fetch*`).

Report repeated instances of one smell as a single finding with a count and two or three representative locations, since ten entries for one pattern drown the rest of the review. With nothing over the threshold, there is no finding.
