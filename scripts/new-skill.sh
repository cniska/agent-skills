#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat >&2 <<'USAGE'
Usage: ./scripts/new-skill.sh <workflow|expertise> <kebab-case-name> <imperative description>

A workflow skill is steps that produce an output; an expertise skill is rules for what good looks like in one kind of work.

Example:
  ./scripts/new-skill.sh expertise api-review "Review API compatibility and contract drift. Use when changing public interfaces."
USAGE
}

if [[ $# -lt 3 ]]; then
  usage
  exit 2
fi

skill_kind="$1"
skill_name="$2"
shift 2
skill_description="$*"

if [[ "$skill_kind" != workflow && "$skill_kind" != expertise ]]; then
  echo "error: skill kind must be workflow or expertise: $skill_kind" >&2
  exit 2
fi

if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: skill name must be kebab-case: $skill_name" >&2
  exit 1
fi

existing="$(compgen -G "$ROOT_DIR/skills/*/$skill_name" || true)"
if [[ -n "$existing" ]]; then
  echo "error: skill directory already exists: $existing" >&2
  exit 1
fi

skill_dir="$ROOT_DIR/skills/$skill_kind/$skill_name"
skill_file="$skill_dir/SKILL.md"

title="$(echo "$skill_name" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++) { $i=toupper(substr($i,1,1)) substr($i,2) }}1')"

mkdir -p "$skill_dir"
cat > "$skill_file" <<EOF_SKILL
---
name: $skill_name
description: $skill_description
---

# $title

State the intent in one short paragraph. Keep it direct and specific.

## Workflow

1. Define scope and success criteria.
2. Read the relevant code and conventions before editing.
3. Execute one focused change at a time.
4. Verify with concrete evidence (tests, checks, or output).
5. Summarize what changed and what is intentionally out of scope.

## See also

- \`<related-skill>\`

## Red flags

- Skipping verification
- Expanding scope mid-task
- Advice without concrete evidence
EOF_SKILL

echo "Created $skill_file"
echo "Next: edit the content, then run mise run validate"
