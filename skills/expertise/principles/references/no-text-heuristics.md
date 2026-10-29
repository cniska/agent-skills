# No text heuristics

Nothing depends on an agent or a user writing certain words. A check, gate, hook, tool or loop never infers what it needs from words in a prompt, Markdown or other prose, such as loading a skill when a regex matches the prompt, or passing a gate when a reply contains "approved". Each writer phrases things its own way, so the inference misfires on the first rewording, and nothing reports the miss.

- What a step needs lives in structured data it parses, such as a JSON field, a tool call's arguments or frontmatter, or in an explicit command or flag that someone runs.
- A regex is fine on a well-defined format, one a program, schema or grammar fixes, such as a log line, a commit hash or a config file.
- Model-written output is prose, even in a format its agent definition or a skill sets, such as a fixed heading or a `Verdict:` line, since a model can drift from a format it is only told to follow.
- The fix moves the signal into data the reader parses, failing loudly when it is missing, and the receiver decides the form:
  - When a tool receives it at hand-off, the writer calls a tool whose input schema the host checks.
  - When a file stores it, the writer writes TOON that a schema checks.
  - Only what a person reads stays prose.
- Widening the pattern to catch the next phrasing is not a fix.
