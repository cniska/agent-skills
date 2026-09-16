#!/usr/bin/env bash
# Unit tests for rules.sh — pure bash, no API calls.
# Run: ./rules.test.sh   (exit 0 = all pass, 1 = failures)
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./rules.sh
source "$HERE/rules.sh" # sourced -> main() does not run

pass=0
fail=0
assert() { # desc got want
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/SKILL.md" <<'EOF'
---
name: demo
description: Do a thing. Use when a thing needs doing.
---

# Demo

A rule in prose.

## Workflow

1. A numbered rule.
- A bullet rule.

```
not-a-rule inside a fence
# not a heading either
```

## Red flags

- A red flag is a rule too
EOF

# rule_lines: frontmatter, headings, blanks and fenced blocks carry no rule.
got="$(rule_lines "$TMP/SKILL.md" | cut -f2-)"
assert "counts only rule-shaped lines" "$(printf '%s\n' "$got" | grep -c .)" 4
assert "skips frontmatter" "$(printf '%s\n' "$got" | grep -c 'description:')" 0
assert "skips headings" "$(printf '%s\n' "$got" | grep -c '^#')" 0
assert "skips fenced content" "$(printf '%s\n' "$got" | grep -c 'not-a-rule')" 0
assert "keeps prose" "$(printf '%s\n' "$got" | grep -c 'A rule in prose')" 1
assert "keeps numbered rules" "$(printf '%s\n' "$got" | grep -c 'A numbered rule')" 1
assert "keeps red flags" "$(printf '%s\n' "$got" | grep -c 'A red flag is a rule too')" 1

# match_count: an address resolves against rule-shaped lines only.
assert "unique address" "$(match_count "$TMP/SKILL.md" 'A numbered rule')" 1
assert "absent address" "$(match_count "$TMP/SKILL.md" 'nowhere in the file')" 0
assert "ambiguous address" "$(match_count "$TMP/SKILL.md" 'rule')" 4
assert "heading is not addressable" "$(match_count "$TMP/SKILL.md" 'Red flags')" 0
assert "fenced line is not addressable" "$(match_count "$TMP/SKILL.md" 'not-a-rule')" 0

# check_address: only a one-line match is usable. Zero means the rule moved and
# the assertion proves nothing; several means it can't say which rule it proves.
assert "address resolving to one line" "$(check_address "$TMP/SKILL.md" demo 'A numbered rule' 2> /dev/null)" ok
assert "address resolving to none" "$(check_address "$TMP/SKILL.md" demo 'nowhere in the file' 2> /dev/null)" error
assert "address resolving to several" "$(check_address "$TMP/SKILL.md" demo 'rule' 2> /dev/null)" error
assert "error names the address" \
  "$(check_address "$TMP/SKILL.md" demo 'rule' 2>&1 > /dev/null | grep -c 'need exactly 1')" 1

# The real inventory reports every skill and stays resolvable: an address that
# matches zero or several lines is an error, so the mapping cannot rot silently.
out="$("$HERE/rules.sh" 2>&1)"
status=$?
assert "inventory exits 0 with resolvable addresses" "$status" 0
assert "inventory reports no errors" "$(printf '%s' "$out" | grep -c '^ERROR')" 0
assert "inventory totals every skill" \
  "$(printf '%s' "$out" | grep -cE '^[a-z][a-z-]* +[0-9]+ rules')" \
  "$(find "$HERE/../skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
assert "inventory counts the wired scenario" \
  "$(printf '%s' "$out" | grep -c 'correctness-review .*[1-9][0-9]* claimed')" 1

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
