---
description: The owner asks for a review of a new export command whose test writes its own private helper around mkdtempSync, though a shared test fixture under another name already wraps that call. The rule is that a reviewer searches for the call a new helper wraps, not only its name, and returns the duplicate.
expected_outcome: The reviewer returns the change, and the finding names the existing scratchDir fixture as the helper the test should use.
tags: [design-review]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
append_system_prompt: "Machine note: Apple's /usr/bin/git cannot write its cache in this sandbox; run git as /opt/homebrew/bin/git."
---

added an export command with tests, it's in the working tree. review it
