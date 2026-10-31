---
name: performance-review
description: Review changed code for repeated, unbounded or blocking work, each tied to the workload that triggers it. Use when a change touches a query, a network call, a loop over input that can grow, or a latency-sensitive path.
---

# Performance Review

Review whether changed code does more work than its workload needs, under the inputs and usage the project supports. A cost no real workload reaches is not worth a fix.

## Scope

### 1. Repeated work

- N+1 queries or requests where a batch, join or prefetch is available
- the same parsing, compilation, serialization or lookup on every pass of a loop
- recomputing a value the surrounding code already caches or memoizes
- the same work repeated across requests, renders, jobs or retries with no stated reason

### 2. Unbounded work and resources

- loops, recursion, queues, logs, memory or retries with no bound the project supports
- a whole unbounded input loaded where the project streams or paginates

### 3. Hot-path cost

- synchronous or blocking work on a latency-sensitive path
- allocations or copies a path shown to be hot does not need
- invalidating or refreshing more than the changed data reaches

## Evidence threshold

Report a cost only with its trigger: the input, request pattern or workload, and the excess work or resource use it causes. Back it with a benchmark, trace, query plan, project budget or concrete input sequence, and say whether it was measured or read from the source. A cost the code and project context cannot show or bound is no finding. When the change claims a speedup, check it was measured against a baseline run under the same conditions, not inferred from a score or code shape.

## Workflow

1. Find the changed path's expected workload in the project docs, its callers and its tests.
2. Trace the queries, requests, loops, allocations, retries and external calls along the path.
3. Size the repeated or unbounded work wherever the code or a measurement allows it.
4. Report each hot spot that meets the threshold.

## Output

Write each hot spot in the `principles` review report: **Why** carries the triggering workload, its cost and the evidence, and **Instead** the fix direction.

With nothing over the threshold, there is no finding.
