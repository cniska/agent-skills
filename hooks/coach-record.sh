#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/subagent-report.sh"

readonly MISSING_PROPOSALS_REASON="End your report with a last line that is exactly 'Proposals: <n>', counting the proposals other than one-offs."

die() {
  printf 'coach-record.sh: %s\n' "$1" >&2
  exit 1
}

block() {
  jq -cn --arg reason "$1" '{decision: "block", reason: $reason}'
}

has_proposals_line() {
  grep -E '^Proposals:' | tail -n 1 | grep -qE '^Proposals: [0-9]+$'
}

main() {
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    die "CLAUDE_PLUGIN_DATA is required"
  fi
  jq --version >/dev/null 2>&1 || die "jq is required to read the coach's report"
  local input stop_hook_active
  input="$(cat)"
  stop_hook_active="$(jq -r '.stop_hook_active // false' <<<"$input")"

  local report
  report="$(subagent_report "$input")"
  if ! has_proposals_line <<<"$report"; then
    [ "$stop_hook_active" = "true" ] || block "$MISSING_PROPOSALS_REASON"
    return
  fi

  local last_run="$CLAUDE_PLUGIN_DATA/coach/last-run"
  mkdir -p "${last_run%/*}"
  date +%s >"$last_run.tmp"
  mv "$last_run.tmp" "$last_run"
}

main "$@"
