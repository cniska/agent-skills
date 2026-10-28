# No text heuristics

Nothing depends on an agent or a user writing certain words. A check, gate, hook, tool or loop never infers what it needs from words in a prompt, Markdown or other prose, such as loading a skill when a regex matches the prompt, or passing a gate when a reply contains "approved". Each writer phrases things its own way, so the inference misfires on the first rewording, and nothing reports the miss.

- What a step needs lives in structured data it parses, such as a JSON field, a tool call's arguments or frontmatter, or in an explicit command or flag that someone runs.
- A regex is fine on a well-defined format, one a program, schema or grammar fixes, such as a log line, a commit hash or a config file.
- The fix moves the signal into data: the writer emits a field or calls a tool, and the reader parses it and fails loudly when it is missing. Widening the pattern to catch the next phrasing is not a fix.
