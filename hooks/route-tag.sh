#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/event-log.sh"

readonly ROUTES_DIR=task/references

route_of() {
  local path="$1" root dir skill
  [[ $path == *.md ]] || return 1
  root="$(cd "$HERE/.." && pwd -P)" || return 1
  dir="$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)" || return 1
  skill="${dir#"$root/skills/"}"
  [ "$skill" != "$dir" ] || return 1
  [ "${skill#*/}" = "$ROUTES_DIR" ] || return 1
  basename "$path" .md
}

main() {
  local input path route
  input="$(cat)"
  path="$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null)" || return 0
  [ -n "$path" ] || return 0
  route="$(route_of "$path")" || return 0
  event_log "$input" tag --arg key route --arg value "$route"
}

main "$@"
