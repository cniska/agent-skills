---
type: regex
target: trace
pattern: '^(?=.*Verdict: (?:return|accept)(?:\\n|\\?"))(?=.*(?:\\n|\b)search(?:\.test|[^.\\]{0,40}\btests?\b))(?=.*(?:\\n|\b)feed(?:\.test|[^.\\]{0,40}\btests?\b))'
flags: im
---
