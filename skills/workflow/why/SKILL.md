---
name: why
description: Explain why existing code or a design has its current shape, from the recorded reason behind it, and whether that reason still holds. Use when asked about a design's rationale, a tradeoff, a threshold or constraint, or a regression tied to an earlier decision.
---

# Why

Find the recorded reason for a design, then check whether it still applies. Current code shows what happens but not what its author intended.

## Workflow

1. **Anchor the question.** Find the code, symbols and behavior it is about. Tell apart why the design was introduced and why it should remain.
2. **Trace the record.** Read the commits that introduced and changed it, following renames and linked pull requests. Check the issues, design docs, tests and comments that touch it. When the repository leaves a gap, search the session or incident records within reach.
3. **Check the present.** Compare the recorded reason with the current callers, contracts and behavior. Name each constraint that has changed since.
4. **Separate evidence from inference.** Call an explicit reason documented, converging clues supported, and a reading of the code alone inference. Report conflicting accounts and gaps.

## Output

Answer the question first. Cite each reason at its source. Keep the original reason apart from the case for keeping the design today. When the reason is unknown, name the records checked and what remains unknown.
