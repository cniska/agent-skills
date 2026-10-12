#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
VALIDATE="$HERE/validate.sh"
TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

pass=0
fail=0
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

V_OUT=""
V_CODE=0
harness() {
  local d
  d="$(mktemp -d "$TMPROOT/case-XXXXXX")"
  mkdir -p "$d/scripts" "$d/skills/demo"
  cp "$VALIDATE" "$d/scripts/validate.sh"
  printf '%s\n' "$d"
}
runv() {
  V_OUT="$(bash "$1/scripts/validate.sh" 2>&1)"
  V_CODE=$?
}
has() {
  if printf '%s\n' "$V_OUT" | grep -qF -- "$1"; then echo yes; else echo no; fi
}

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: Review a change for problems. Use when reviewing a diff.
---

# Demo

One line of intent.

## Red flags

- A failure mode
EOF
runv "$d"
assert "well-formed: exit 0"     "$V_CODE" 0
assert "well-formed: reports OK" "$(has 'OK: skill validation passed')" yes

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: Review a change for problems. Use when reviewing a diff.
---

# Demo

Read the repo's CLAUDE.md before running Claude Code.

## Red flags

- A failure mode
EOF
runv "$d"
assert "Claude names a tool, not a model: exit 0" "$V_CODE" 0

d="$(harness)"
runv "$d"
assert "missing SKILL.md: exit 1"  "$V_CODE" 1
assert "missing SKILL.md: message" "$(has 'missing SKILL.md')" yes

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
---
name: other
description: Review a change. Use when reviewing.
---

# Demo

## Red flags

- x
EOF
runv "$d"
assert "name mismatch: exit 1"  "$V_CODE" 1
assert "name mismatch: message" "$(has 'must match directory')" yes

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: Review a change. Use when reviewing.
---

# Demo

No red flags here.
EOF
runv "$d"
assert "no red flags: exit 1"  "$V_CODE" 1
assert "no red flags: message" "$(has "missing '## Red flags'")" yes

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: Review a change. Use when reviewing.
---

# Demo

## Anti-patterns

- x
EOF
runv "$d"
assert "anti-patterns: exit 1"  "$V_CODE" 1
assert "anti-patterns: message" "$(has "use '## Red flags' instead")" yes

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: Quickly patches things. Use when needed.
---

# Demo

## Red flags

- x
EOF
runv "$d"
assert "non-imperative: exit 1"  "$V_CODE" 1
assert "non-imperative: message" "$(has 'imperative verb')" yes

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: Review a change. Use when reviewing.
---

# Demo

See [the checklist](references/checklist.md).

## Red flags

- x
EOF
runv "$d"
assert "missing reference: exit 1"  "$V_CODE" 1
assert "missing reference: message" "$(has "link 'references/checklist.md' in demo must name a file inside the skill's own directory")" yes

mkdir -p "$d/skills/demo/references"
printf '# Checklist\n' > "$d/skills/demo/references/checklist.md"
runv "$d"
assert "present reference: exit 0" "$V_CODE" 0

printf '# Checklist\n\nRun it on GPT-4.\n' > "$d/skills/demo/references/checklist.md"
runv "$d"
assert "model in reference: exit 1"  "$V_CODE" 1
assert "model in reference: message" "$(has "named model in $d/skills/demo/references/checklist.md")" yes

printf '# Checklist\n\nSee [the rules](../SKILL.md#red-flags).\n' > "$d/skills/demo/references/checklist.md"
runv "$d"
assert "reference links up to SKILL.md: exit 0" "$V_CODE" 0

printf '# Checklist\n\nSee [the checklist](references/checklist.md).\n' > "$d/skills/demo/references/checklist.md"
runv "$d"
assert "reference link resolved from the skill root: exit 1" "$V_CODE" 1

d="$(harness)"
cat > "$d/skills/demo/SKILL.md" <<'EOF'
# Demo

No frontmatter at all.

## Red flags

- x
EOF
runv "$d"
assert "no frontmatter: exit 1"  "$V_CODE" 1
assert "no frontmatter: message" "$(has 'missing YAML frontmatter')" yes

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
