---
name: performance-review
description: Review performance risks in changed code — repeated work, unbounded operations, and resource misuse. Use when reviewing a change for runtime cost or scalability.
---

# Performance Review

Review whether changed code does unnecessary or unbounded work under the inputs and usage patterns the project supports.

## Scope

### 1. Repeated work

- N+1 queries or requests where a batch, join, or prefetch is available
- repeated parsing, compilation, serialization, or lookup inside a loop
- recomputation where the surrounding code establishes a cache or memoization boundary

### 2. Unbounded work and resources

- loops, recursion, queues, logs, memory, or retries without a project-supported bound
- loading an entire unbounded input when streaming or pagination is the established pattern
- work duplicated across requests, renders, jobs, or retries without an explicit reason

### 3. Hot-path cost

- synchronous or blocking work on a latency-sensitive path
- unnecessary allocations or copies in a demonstrated hot path
- broad invalidation or refresh where the changed data has a narrower scope

### 4. Measurement and tradeoffs

- performance claims supported by a benchmark, trace, query plan, project budget, or concrete input sequence
- measured findings kept separate from static hypotheses
- fixes verified under equivalent conditions rather than inferred from a score or code shape alone

## Evidence threshold

Flag a performance issue only with a concrete trigger: name the input, request pattern, or workload and the excess work or resource use it causes. Do not report a generic concern that might be slow. If the cost cannot be demonstrated or bounded from the code and project context, report no finding.

## Workflow

1. Identify the changed path and its expected workload from project docs, callers, and tests.
2. Trace queries, requests, loops, allocations, retries, and external calls across the path.
3. Quantify repeated or unbounded work where possible; distinguish measurements from source-only hypotheses.
4. Report concrete findings, with the trigger and fix direction.

## Output

Write each hot spot in the `principles` review report: **Why** carries the triggering workload, its impact and the evidence, and **Instead** the fix direction.

With nothing over the threshold, there is no finding.
