# No text heuristics

Make each step read what it needs from structured data or an explicit command, rather than infer it from the words of a prompt or other prose.

Each writer phrases things its own way, so an inference from wording misfires silently on the first rewording.

- Put what a step needs in data it parses, such as a JSON field, a tool call's arguments or frontmatter, or in a command or flag someone runs.
- Fail loudly when that data is missing.
- Use a regex only on a format a program, schema or grammar fixes, such as a log line or a commit hash.
- Treat model-written output as prose, even in a format its agent definition or a skill sets, such as a fixed heading or a `Verdict:` line.
- Choose the form of what a step needs by who receives it:
  - A tool that receives it at hand-off takes a call whose input schema is checked before the call.
  - A file that stores it holds TOON that a schema checks.
  - Only what a person reads stays prose.

Example: a gate that passed when a reply contained "approved" now passes on the verdict field of the reviewer's tool call.
