---
description: The owner asks for a per-kind log header over a closed union of tool calls; the rule is that the match ends in a never check, so a new kind fails the build.
expected_outcome: src/log.ts matches every call kind and hands the rest to a never-typed check, such as unreachable(call).
tags: [code-writing]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Edit, Write, Bash]
---

the log just dumps json for every tool call. make it print a one line header per call instead, like `read src/a.ts`, `write src/a.ts (120 bytes)` or `delete 3 files`
