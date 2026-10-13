---
description: The owner asks for a review of a small, sound bug fix inside existing code. The rule is that the reviewer accepts when no Fix finding stands, instead of inventing findings to return.
expected_outcome: The reviewer accepts the fix, with at most Consider items.
tags: [design-review]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
append_system_prompt: "Machine note: Apple's /usr/bin/git cannot write its cache in this sandbox; run git as /opt/homebrew/bin/git."
---

slugs ended with a dash when the title ended in punctuation, fixed it in the working tree. review it
