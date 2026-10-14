# The loops

The workflow runs in three loops, as the [README](../README.md#three-loops) shows at a glance. Each chart here shows one loop and its handoffs to the others.

## The inner loop

One agent runs one task, from its route to a landed commit.

```mermaid
flowchart LR
  route["Route"] --> steps["Steps load their skills"]
  steps --> rev["Fresh reviewer"]
  rev --> commit["Commit"]
  commit -- "report" --> lead["Coordinator"]
  commit -- "sessions and events" --> rec[("agent-record")]
```

## The outer loop

The coordinator runs all the work in one long session on autocompaction.

```mermaid
flowchart LR
  you(["You"]) -- "the work" --> lead["Coordinator"]
  lead -- "batched questions" --> you
  lead -- "reads and rewrites" --> ledger[("Ledger")]
  lead -- "delegates a task" --> inner["Inner loop"]
  lead -- "experiment record, via the due note" --> coach["Coach"]
```

## The improvement loop

The coach turns the record of past work into proposals for the coordinator.

```mermaid
flowchart LR
  rec[("agent-record")] -- "signals" --> coach["Coach"]
  coach -- "proposals, keep or revert" --> lead["Coordinator"]
```
