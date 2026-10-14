#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"
source "$HERE/subagent-report.sh"
source "$HERE/event-log.sh"

readonly MISSING_VERDICT_REASON="End your report with a last line that is exactly 'Verdict: accept' or 'Verdict: return'."
readonly MISSING_REPO_REASON="Put 'Repo: <absolute path of the repository under review>' on the line above the verdict."
readonly REPORT_SHAPE="The report is three sections, '## Findings', '## Conflicts' and '## Clean', each saying 'none' when it is empty; each finding is four bullets, '- **Where:**', '- **Rule:** <the rule's heading>', '- **Why:**' and '- **Instead:**'; then 'Repo: <absolute path>' and 'Verdict: accept' or 'Verdict: return' as the last two lines."
readonly MISSING_FINDINGS_REASON="The report lacks a section. $REPORT_SHAPE"
readonly ACCEPT_WITH_FINDINGS_REASON="An accept needs 'none' under '## Findings'; while any finding stands, end with 'Verdict: return'. $REPORT_SHAPE"

die() {
  printf 'review-record.sh: %s\n' "$1" >&2
  exit 1
}

malformed_report() {
  local input="$1" stop_hook_active="$2" code="$3" reason="$4" decision=deny
  if [ "$stop_hook_active" = "true" ]; then
    decision=allow
  fi
  event_log "$input" gate --arg gate verdict --arg decision "$decision" --arg reason "$code" \
    --arg repo "" --arg head "" --arg fingerprint ""
  [ "$decision" = allow ] || jq -cn --arg reason "$reason" '{decision: "block", reason: $reason}'
}

verdict_of() {
  grep -Eo '^Verdict: (accept|return)$' | tail -n 1 | cut -d ' ' -f 2 || true
}

return_reason() {
  grep -Eo '^Reason: no_diff$' | tail -n 1 | cut -d ' ' -f 2 || true
}

has_sections() {
  local report heading
  report="$(cat)"
  for heading in Findings Conflicts Clean; do
    grep -qx "## $heading" <<<"$report" || return 1
  done
}

findings_empty() {
  awk '/^## /{inside = ($0 == "## Findings"); next} inside && NF {n++; if (tolower($0) !~ /^none\.?$/) found = 1} END {exit !(n == 1 && !found)}'
}

named_repo() {
  grep -E '^Repo: ' | tail -n 1 | cut -d ' ' -f 2- || true
}

main() {
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    die "CLAUDE_PLUGIN_DATA is required"
  fi
  jq --version >/dev/null 2>&1 || die "jq is required to read the reviewer's verdict"
  local input stop_hook_active
  input="$(cat)"
  stop_hook_active="$(jq -r '.stop_hook_active // false' <<<"$input")"

  local report verdict named
  report="$(subagent_report "$input")"
  verdict="$(verdict_of <<<"$report")"
  named="$(named_repo <<<"$report")"
  if [ -z "$verdict" ]; then
    malformed_report "$input" "$stop_hook_active" missing_verdict "$MISSING_VERDICT_REASON"
    return
  fi

  local repo
  if [ -z "$named" ]; then
    malformed_report "$input" "$stop_hook_active" missing_repo "$MISSING_REPO_REASON"
    return
  elif [[ $named != /* ]]; then
    malformed_report "$input" "$stop_hook_active" repo_relative "'$named' is not an absolute path. $MISSING_REPO_REASON"
    return
  elif ! repo="$(repo_root "$named")" || [ -z "$repo" ]; then
    malformed_report "$input" "$stop_hook_active" repo_not_found "'$named' is not a repository. $MISSING_REPO_REASON"
    return
  fi

  local state fingerprint
  state="$(review_state_file "$repo")"
  [ "$verdict" = accept ] || rm -f "$state"
  if ! has_sections <<<"$report"; then
    malformed_report "$input" "$stop_hook_active" missing_findings "$MISSING_FINDINGS_REASON"
    return
  elif [ "$verdict" = accept ] && ! findings_empty <<<"$report"; then
    malformed_report "$input" "$stop_hook_active" accept_with_findings "$ACCEPT_WITH_FINDINGS_REASON"
    return
  fi

  fingerprint="$(diff_fingerprint "$repo")"
  if [ "$verdict" = accept ]; then
    mkdir -p "$(dirname "$state")"
    printf '%s\n' "$fingerprint" >"$state.tmp"
    mv "$state.tmp" "$state"
  fi
  event_log "$input" verdict --arg verdict "$verdict" --arg repo "$repo" --arg fingerprint "$fingerprint" \
    --arg reason "$(return_reason <<<"$report")"
}

main "$@"
