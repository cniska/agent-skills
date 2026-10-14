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

shopt -u patsub_replacement 2>/dev/null || true
template="$(cat "$ROOT_DIR/SKILL_TEMPLATE.md")"
template="${template//<skill-name>/$skill_name}"
template="${template//<imperative sentence describing when to use this skill>/$skill_description}"
template="${template//<Skill title>/$title}"

mkdir -p "$skill_dir"
printf '%s\n' "$template" >"$skill_file"

echo "Created $skill_file"
echo "Next: edit the content, then run mise run validate"
