#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/subagent-gate.sh"

readonly MISSING_PROPOSALS_REASON="End your report with a last line that is exactly 'Proposals: <n>', counting the proposals other than one-offs."

die() {
  printf 'coach-report.sh: %s\n' "$1" >&2
  exit 1
}

has_proposals_line() {
  grep -E '^Proposals:' | tail -n 1 | grep -qE '^Proposals: [0-9]+$'
}

main() {
  jq --version >/dev/null 2>&1 || die "jq is required to read the coach's report"
  local input report
  input="$(cat)"
  judges "$input" cniska-skills:coach || return 0
  ! left_to_handback "$input" || return 0
  report="$(subagent_report "$input")"
  has_proposals_line <<<"$report" && return
  deny_once "$input" missing_proposals "$MISSING_PROPOSALS_REASON" || return 0
}

main "$@"
