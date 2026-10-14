---
type: regex
target: { source: file, path: src/config.ts }
pattern: '\bas (?!const\b|unknown\b)(?:any\b|string\b|number\b|boolean\b|object\b|typeof\b|[A-Z"''{\[(]|z\.)'
match: not_contains
---
