---
name: correctness-review
description: Review whether changed logic does what it claims, finding wrong conditions, unhandled edge cases, async mistakes and broken caller contracts, each shown by an input that breaks it. Use when reviewing any diff, since these bugs pass type checks, linters and the other review areas.
---

# Correctness Review

Review whether changed code does what it claims. Look for the bugs that pass type-checking and linting yet give wrong results, since style, boundaries, coverage and docs can all be clean while the logic is wrong.

## Scope

### 1. Logic

- an inverted or off-by-one condition, or the wrong comparison or boolean operator
- the wrong variable or field, or arguments in the wrong order
- a calculation that gives the wrong result for a valid input

### 2. Edge cases

- empty, null, zero, negative or maximum inputs left unhandled
- a missing early return or default branch, so the code silently skips a case
- a boundary where behavior flips: first or last, inclusive or exclusive

### 3. Control flow and async

- a missing `await`, an unhandled rejection, or fire-and-forget where the caller must wait for the work to finish
- errors swallowed or caught too broadly, a failure path that returns success, or a substituted default the caller cannot tell from a real value
- unreachable code, or a branch nothing can enter

### 4. Contract

- a function that does not do what its name, signature or doc claims
- a caller's assumption the change breaks, such as return shape, nullability or ordering
- shared state mutated without a guard against a race, or written where callers do not expect it

## Evidence threshold

Report a bug only with its trigger: the input or sequence and the wrong result it gives. A concern you cannot tie to an input that breaks the code is no finding.

## Workflow

1. Read the diff and enough surrounding code to know what each change is meant to do.
2. For each change, find the input or interleaving that makes it do the wrong thing, tracing actual behavior against claimed behavior.
3. Read the tests of the changed path. When a green suite passes around wrong behavior, report the test as wrong too.

## Output

Use the review report from `principles`. Each bug's **Rule** is its Scope bucket, its **Why** the triggering input and the wrong result it gives, and its **Instead** the fix direction.

- Bad: "This function looks fragile and could misbehave." (no trigger)
- Good: **Why:** `pricing.ts:40` `applyDiscount` uses `>` not `>=`, so an order exactly at the threshold gets nothing (total 100, threshold 100 → 0% instead of 10%).

When no concrete input breaks the code, there is no finding.
