---
name: maintainability-review
description: Review code maintainability, naming, patterns, and consistency. Use when reviewing code quality or changeability.
---

# Maintainability Review

Review whether the code is easy to understand, change, and extend against the codebase's existing conventions. Rules that hold regardless of local convention — control flow, constants, indirection, comments — are `code-writing`'s and `design-review`'s.

## Scope

### 1. Naming and organization

- naming consistency across types, constants, functions, and files
- names that describe their content rather than their category, judged in context: a bare `data`, `temp`, or `result` holding something specific is the smell, but the same word is right where it is the domain's own term, a published API name, or an accumulator the function builds and returns — check the spec and the exports before flagging one
- renamed concepts stay aligned across code, tests, docs, and exported identifiers
- constructor and factory naming follows a single project convention
- module and file layout follows the established project structure
- import/export patterns are consistent across the codebase

### 2. Control flow and state modeling

- consistent assertion and error patterns
- prefer data-driven lookups over long control-flow chains; likewise for one predicate re-tested throughout a body, and for a dispatch whose arms share an implementation. Not an exhaustive match over a closed type — a lookup table there trades a compile-time guarantee for a runtime one
- one error boundary per failure mode: nested or back-to-back `try` blocks mean the boundary hasn't been decided — extract each fallible step into a function that handles or propagates

### 3. Pattern consistency

Check where the codebase already has a clear local pattern:

- structural patterns (table-driven, rule-driven) where nearby code uses them
- error classification follows the project's established convention
- repeated argument groups that want one named type
- sibling concepts with different intent should not collapse into one ambiguous shape or name

### 4. Readability and changeability

- a comment the project's comment rule does not allow
- no unused params, dead branches, or ad-hoc fallbacks
- a new suppression of a type, lint, or security check in config or an attribute, or a stub standing where the work should be — an unimplemented throw, an empty catch turning a failure into silence. Flag a suppression unless no rewrite of the code meets the check without making it worse and the config entry, or the attribute's reason, says why; flag a stub unless the diff says why
- keep structure and terminology aligned with nearby code
- prefer clear, idiomatic code over cleverness

## Evidence threshold

Sections 1 and 3 require evidence of a local convention — cite the nearby code that establishes it. Sections 2 and 4 are default checks that apply without repo evidence, but rate them **minor** unless a documented convention raises them.

A suppression comment is the exception: the comment rule refuses it, so rate it **major**.

## Workflow

1. Identify local style conventions from nearby code.
2. Compare against repo-wide documented conventions.
3. Find concrete deviations with evidence.
4. Report each deviation with its evidence.

## Output

Follow the review report in `principles`. For each departure from convention, **Rule** names the convention, **Why** cites both the offending line and the code that establishes the convention, and **Instead** gives the fix direction.

- Bad: "`getUserData` — inconsistent, should be `fetchUserData`." (no evidence)
- Good: **Why:** `src/api/user.ts:12` `getUserData` breaks the fetch-prefix convention (9 of 10 siblings in `src/api/` use `fetch*`).

If nothing clears the threshold, Findings is `none` — don't pad. Aggregate repeated instances of one smell into a single finding carrying a count and two or three representative locations; ten separate entries for one pattern drown the review they sit in.

## See also

- `design-review` and `code-writing` for the rules that hold regardless of local convention
- `simplify` for performing the cleanups this review identifies
- `principles` for the review report every departure is given in

## Red flags

- Enforcing generic style dogma over local conventions
- Broad rewrites instead of minimal fixes
- Restating a `design-review` finding under Maintainability
- Nitpicking formatting not tied to repo conventions
