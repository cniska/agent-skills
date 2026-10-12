---
type: regex
target: { source: file, path: src/config.ts }
pattern: '\b(\w+)\s*=\s*z\.[\s\S]*?\b\1\.(?:safeParse|parse)\(|z\.\w*Object\(\{[\s\S]*?\}\)\.(?:safeParse|parse)\('
---
