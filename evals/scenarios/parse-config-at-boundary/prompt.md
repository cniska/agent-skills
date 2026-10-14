---
description: The owner asks to move settings out of the env into a config file; the rule is a strict zod parse at the boundary with no cast and no hand-written type beside the schema.
expected_outcome: src/config.ts parses the config file through a z.strictObject schema, with no cast, non-null assertion or hand-written type beside it.
tags: [code-writing]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Edit, Write, Bash]
---

move all non-secrets to a config file
