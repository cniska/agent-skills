---
name: why
description: Explain why existing code or design has its current shape. Use for design rationale, tradeoffs, historical constraints, thresholds, and regressions tied to earlier decisions.
---

# Why

Find the recorded reason for a design, then check whether it still applies. Current code shows what happens; it does not prove what its author intended.

## Workflow

1. **Anchor the question.** Find the relevant code, symbols, and behavior. Distinguish why it was introduced from why it should remain.
2. **Trace the record.** Read the commits that introduced and changed it, following renames and linked PRs. Check relevant issues, design docs, tests, and comments. Search available session or incident records when the repository leaves a gap.
3. **Check the present.** Compare the recorded reason with current callers, contracts, and behavior. Name any constraint that has changed.
4. **Separate evidence from inference.** Treat an explicit reason as documented, converging clues as supported, and a reading of the code alone as inference. Report conflicting accounts and gaps.

## Output

Answer the question first. Cite each reason at its source. Distinguish the original reason from the case for keeping the design today. If the reason is unknown, name the records checked and what remains unknown.

## See also

- `search-sessions` for decisions recorded in earlier conversations
- `explain-diff` for the intent and risk of a specific change
- `debug` when the question starts with a current failure

## Red flags

- Inferring author intent from code alone
- Treating the latest commit as the whole history
- Presenting a plausible explanation as a recorded decision
- Claiming an old constraint still applies without checking it
- Hiding conflicting sources or an unsuccessful search
