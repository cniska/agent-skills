---
type: regex
target: { source: file, path: src/config.ts }
pattern: '[\w)\]]!(?=[.;,)\[\]]|\s*[;,)\n])'
match: not_contains
---
