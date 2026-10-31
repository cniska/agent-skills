---
name: plan
description: Design a feature or behavior change with the owner before code is written, settling its shape, its slices and the questions only they can answer. Use when asked to plan, scope, design or break down work, or when a task's shape is unclear.
---

# Plan

Design a change through dialogue with the owner, so the shape they agree to is the one that gets built. Start from the issue when one is given. Run `search-sessions` for what earlier sessions already designed or ruled out for this change.

## What matters

- **Question the premise.** The framed change is a proposal. Ask whether it is the right unit of work, whether removing something would serve better than adding, and whether the feature still earns its keep. Prefer deletion and fixes at the source to accretion. When the framing is off, say so before designing to it.
- **Build the plan in the dialogue.** Read the code the change touches, share what you find, say what you think, and let the owner steer. Bring your findings back to them before drafting, as a turn of the conversation.
- **Ground every recommendation** in current code, docs and project rules. Read enough yourself to know which files carry the change before fanning work out to subagents ([research](references/research.md)).
- **Settle what evidence settles.** A hard technical question, such as whether a pattern exists, which shape fits this codebase or what a migration costs, has an evidence-based answer, so it is yours. When an open file or one search settles it, settle it and state the grounding. When it needs real work, give it to a powerful-tier subagent and come back with the answer and its grounding.
- **Ask the owner only what evidence cannot settle:** product intent, priority, risk appetite and which tradeoff they want to live with. Split a mixed question, settle its evidence half, and ask only the rest. Before each question, name what you tried first. Ask one question at a time, in dependency order, each with your recommended answer. Research raises new questions, so judge each new one the same way as it arrives.
- **Size by decisions.** Count the files that carry a decision a reviewer could push back on: mechanical churn and doc or spec updates that mirror a decision already made add none, and a file that carries several decisions counts as several. By that count, 1 to 2 is a small slice, 3 to 5 is one feature slice through the stack, and 5 to 8 is large and worth splitting. Split anything past 8. Slice vertically, each slice a complete path through the stack.
- **Make the shape concrete** for a change past one file, while a decision is still cheap to change ([program design](references/program-design.md)).

## With no one to ask

When the plan runs from a subagent, a schedule or a batch run, nobody can answer. State each question as a marked assumption, carrying the answer you would have recommended and the cost of the alternative, and keep going. Show your evidence in the plan's grounding in place of the read-back. Label the plan unratified at its top, and give the checklist unchecked as the proposed sequence, so nothing reads as agreed.

## When aligned

The plan is aligned once the owner has explicitly agreed to a concrete proposal. Hearing it is not agreeing to it.

- Summarize what was agreed: **Outcome** | **Decisions made** | **Change list** | **Validation** | **Open questions**.
- Split large work into phases, each valuable and verifiable on its own, naming concrete files.
- For any plan past one small step, keep the agreed steps in a checklist as the conversation goes. When planning is done, hand the checklist to the owner and stop. Execution starts when the owner says so, usually through `build`.
