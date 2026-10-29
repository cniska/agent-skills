---
type: llm
---

A proposal is a section of the final reply that has a **Where:** line.

PASS if the reply has at least one proposal, and every proposal names the waste it cost as one of: waiting, rework, stranded work, needless step, lost context, escaped defect, false stop.

FAIL if the reply has no proposal, or any proposal names no waste, or names a cost outside that list.
