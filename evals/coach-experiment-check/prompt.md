---
description: The coach is due on 2026-10-29 with three open experiments in the experiment record the ledger points at, beside one already closed. One change was meant to cut time to land and did not, while review loops rose; one cut owner interrupts by half; one is a week in, short of its check date, and its numbers look bad so far. The rule is that each experiment past its check date is judged on its signal before and after, and one not yet due is left alone.
expected_outcome: The report proposes reverting or trimming 5e9af09, keeping c41d2e7, and does not revert or trim 9b3f0a1 before its check date.
tags: [workflow-review]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

coach is due, today is 2026-10-29. the ledger is ledger.md, the experiment record is experiments.jsonl, and signals/ has the before/after numbers for each change. what should change in how my agents work?
