---
type: regex
target: { source: file, path: src/config.ts }
pattern: '\binterface\s+\w|\btype\s+\w+\s*=\s*(?:\{|["''])'
match: not_contains
---
