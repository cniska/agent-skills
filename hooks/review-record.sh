#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"
source "$HERE/subagent-report.sh"
source "$HERE/event-log.sh"

readonly MISSING_VERDICT_REASON="End your report with a last line that is exactly 'Verdict: accept' or 'Verdict: return'."
readonly MISSING_REPO_REASON="Put 'Repo: <absolute path of the repository under review>' on the line above the verdict."
readonly REPO_REPEATED_REASON="Give each repository one verdict: name it in one 'Repo:' line only."
readonly REPORT_SHAPE="The report is three sections, '## Findings', '## Conflicts' and '## Clean', each saying 'none' when it is empty; each finding is four bullets, '- **Where:**', '- **Rule:** <the rule's heading>', '- **Why:**' and '- **Instead:**'; then, at the end, 'Repo: <absolute path>' with 'Verdict: accept' or 'Verdict: return' on the line below it, one such pair per repository."
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

verdict_pairs() {
  awk '/^Reason: no_diff$/{reason = substr($0, 9); repo = ""; next} /^Repo: /{repo = substr($0, 7); next} /^Verdict: (accept|return)$/ {print substr($0, 10) "\037" repo "\037" (repo == "" ? "" : reason)} NF {repo = ""; reason = ""}'
}

named_before() {
  local repo="$1" seen
  shift
  for seen in "$@"; do
    [ "$seen" != "$repo" ] || return 0
  done
  return 1
}

main() {
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    die "CLAUDE_PLUGIN_DATA is required"
  fi
  jq --version >/dev/null 2>&1 || die "jq is required to read the reviewer's verdict"
  local input stop_hook_active
  input="$(cat)"
  stop_hook_active="$(jq -r '.stop_hook_active // false' <<<"$input")"

  local report pairs
  report="$(subagent_report "$input")"
  pairs="$(verdict_pairs <<<"$report")"
  if [ -z "$pairs" ]; then
    malformed_report "$input" "$stop_hook_active" missing_verdict "$MISSING_VERDICT_REASON"
    return
  fi

  local verdicts=() repos=() reasons=() verdict named reason repo accepts=0 code="" why="" pair_code pair_why
  while IFS=$'\037' read -r verdict named reason; do
    pair_code=""
    if [ -z "$named" ]; then
      pair_code=missing_repo pair_why="$MISSING_REPO_REASON"
    elif [[ $named != /* ]]; then
      pair_code=repo_relative pair_why="'$named' is not an absolute path. $MISSING_REPO_REASON"
    elif ! repo="$(repo_root "$named")" || [ -z "$repo" ]; then
      pair_code=repo_not_found pair_why="'$named' is not a repository. $MISSING_REPO_REASON"
    else
      [ "$verdict" = accept ] || rm -f "$(review_state_file "$repo")"
      if named_before "$repo" ${repos[@]+"${repos[@]}"}; then
        pair_code=repo_repeated pair_why="'$named' has more than one verdict. $REPO_REPEATED_REASON"
      fi
    fi
    if [ -n "$pair_code" ]; then
      [ -n "$code" ] || code="$pair_code" why="$pair_why"
      continue
    fi
    verdicts+=("$verdict")
    repos+=("$repo")
    reasons+=("$reason")
    [ "$verdict" = return ] || accepts=$((accepts + 1))
  done <<<"$pairs"
  if [ -n "$code" ]; then
    malformed_report "$input" "$stop_hook_active" "$code" "$why"
    return
  fi

  if ! has_sections <<<"$report"; then
    malformed_report "$input" "$stop_hook_active" missing_findings "$MISSING_FINDINGS_REASON"
    return
  elif [ "$accepts" -gt 0 ] && ! findings_empty <<<"$report"; then
    malformed_report "$input" "$stop_hook_active" accept_with_findings "$ACCEPT_WITH_FINDINGS_REASON"
    return
  fi

  local i state fingerprint
  for i in "${!repos[@]}"; do
    state="$(review_state_file "${repos[$i]}")"
    fingerprint="$(diff_fingerprint "${repos[$i]}")"
    if [ "${verdicts[$i]}" = accept ]; then
      mkdir -p "$(dirname "$state")"
      printf '%s\n' "$fingerprint" >"$state.tmp"
      mv "$state.tmp" "$state"
    fi
    event_log "$input" verdict --arg verdict "${verdicts[$i]}" --arg repo "${repos[$i]}" --arg fingerprint "$fingerprint" \
      --arg reason "${reasons[$i]}"
  done
}

main "$@"
