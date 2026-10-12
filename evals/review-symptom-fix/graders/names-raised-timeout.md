---
type: regex
target: trace
pattern: '^(?=.*Verdict: (?:return|accept)(?:\\n|\\?"))(?=.*(?:\\n|[^\w.,])8(?:[,_]?000(?!\d)|\s?s(?:ec(?:ond)?s?)?\b))'
flags: im
---
