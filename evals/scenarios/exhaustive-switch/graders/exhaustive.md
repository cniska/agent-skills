---
type: regex
target: { source: file, path: src/log.ts }
pattern: ':\s*never\b|satisfies\s+never\b|\b\w*(?:unreachable|exhaustive|absurd|impossible|never)\w*\(\s*[\w$.]+\s*[,)]'
flags: i
---
