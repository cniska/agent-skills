# How I maintain these

These are built for my own use, in my own tone and decision style. The goal is consistent execution quality across sessions, not generic prompt patterns.

I run the whole set with an `AGENTS.md` in every repo. Skills defer to it for project-specific facts, such as verify and release commands, invariants and conventions, rather than restating them. Each skill still installs and runs on its own, and falls back to sensible defaults in a repo without one. Use the [agents-md](../skills/workflow/agents-md/SKILL.md) skill to create that file first.

What feeds the maintenance: daily use in my own projects, gaps observed in real sessions, selective upstream review as a signal, and external feedback when it aligns with these principles.

I add guidance when it:

- repeats in real work
- improves quality, speed, or risk profile
- can be verified with concrete checks
- fits the way I want agents to operate

I remove or simplify guidance when it:

- no longer changes outcomes, often because models now do it without being told
- becomes outdated
- duplicates other skills
- drifts toward generic "corp" voice without adding value

Where a rule must hold, I enforce the outcome rather than every step: the reviewer judges the result, and the routes keep only the steps that change it.

The [improvement loop](loops.md#the-improvement-loop) runs this on evidence, and [development](development.md) has the setup and checks.
