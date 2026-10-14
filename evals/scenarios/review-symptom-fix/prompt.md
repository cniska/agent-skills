---
description: The owner asks for a review of a fix that mocks a shared loading floor in one test file. The rule is that a symptom fix is returned, and the finding names the cause and every other place with the same cause, including a sibling test's raised timeout.
expected_outcome: The reviewer returns the fix, and the report names the search and feed tests and the feed test's raised 8000 ms timeout as the same cause, fixed once at the loading floor.
tags: [design-review]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
append_system_prompt: "Machine note: Apple's /usr/bin/git cannot write its cache in this sandbox; run git as /opt/homebrew/bin/git."
---

the profile tests kept timing out, i put a fix in the working tree. review it
