# Diagrams

Which chart a doc needs, how to write it, and the check that renders it.

## When a chart beats prose or a table

- **Draw it when the reader must follow a path or hold a shape**: steps that branch or loop, parts that pass messages in turn, modes and what moves between them, or records and how they relate. Prose makes the reader build that picture in their head.
- **Keep a table for values side by side**, such as options, columns or tiers, and prose for a straight sequence of a few steps or for reasons.

## Pick the chart by the question

| Question | Mermaid chart |
|---|---|
| What happens, step by step, and where does it branch? | `flowchart` |
| Who sends what to whom, in what order? | `sequenceDiagram` |
| Which modes can it be in, and what moves it between them? | `stateDiagram-v2` |
| Which records exist, and how do they relate? | `erDiagram` |

## Write it

- **One question per chart**, judged by whether a reader understands it at a glance, not by its size: short node names, edge labels of a few words and a handful of nodes usually get it there. The prose beside it stays the source and holds the caveats.
- **Labels in the reader's words**, the terms the doc around it uses, never function, class or variable names.

## Why Mermaid

GitHub renders a ```mermaid block in Markdown natively, so the chart stays text: it can be diffed, reviewed and changed in the same commit as its doc. D2 and Graphviz need a rendered image committed beside the source, which drifts from it. Use Mermaid unless the repo already draws its charts another way.

## Render check

- **The repo checks every chart.** A repo with charts pins Mermaid's CLI, `@mermaid-js/mermaid-cli` with its `mmdc` command, in its own tool setup, as `code-writing` says. One task runs `mmdc` on every Mermaid block in the repo's Markdown, and the repo's check entry point calls it, so a syntax error that GitHub would show as a broken block fails the check.
- **Look at a changed chart.** Render it to PNG and read the image, since a chart that parses can still cross its lines or cut its labels.
- **Proven able to fail**, as `principles` says: the task goes red once on a deliberately broken chart before it is trusted.
