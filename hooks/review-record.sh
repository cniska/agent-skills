#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=review-state.sh
source "$HERE/review-state.sh"

readonly MISSING_VERDICT_REASON="End your report with a last line that is exactly 'Verdict: accept' or 'Verdict: return'."
readonly MISSING_REPO_REASON="Put 'Repo: <absolute path of the repository under review>' on the line above the verdict."

die() {
  printf 'review-record.sh: %s\n' "$1" >&2
  exit 1
}

block() {
  jq -cn --arg reason "$1" '{decision: "block", reason: $reason}'
}

handback_report() {
  local transcript="$1"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "SubagentHandback") | .input.message // empty' "$transcript"
}

verdict_of() {
  grep -Eo '^Verdict: (accept|return)$' | tail -n 1 | cut -d ' ' -f 2 || true
}

named_repo() {
  grep -E '^Repo: ' | tail -n 1 | cut -d ' ' -f 2- || true
}

main() {
  : "${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is required}"
  jq --version >/dev/null 2>&1 || die "jq is required to read the reviewer's verdict"
  local input transcript last_message stop_hook_active
  input="$(cat)"
  transcript="$(jq -r '.agent_transcript_path // empty' <<<"$input")"
  last_message="$(jq -r '.last_assistant_message // empty' <<<"$input")"
  stop_hook_active="$(jq -r '.stop_hook_active // false' <<<"$input")"

  local report verdict named
  report="$(printf '%s\n%s\n' "$(handback_report "$transcript")" "$last_message")"
  verdict="$(verdict_of <<<"$report")"
  named="$(named_repo <<<"$report")"
  if [ -z "$verdict" ]; then
    [ "$stop_hook_active" = "true" ] || block "$MISSING_VERDICT_REASON"
    return
  fi

  local repo reason=""
  if [ -z "$named" ]; then
    reason="$MISSING_REPO_REASON"
  elif [[ $named != /* ]]; then
    reason="'$named' is not an absolute path. $MISSING_REPO_REASON"
  elif ! repo="$(repo_root "$named")" || [ -z "$repo" ]; then
    reason="'$named' is not a repository. $MISSING_REPO_REASON"
  fi
  if [ -n "$reason" ]; then
    [ "$stop_hook_active" = "true" ] || block "$reason"
    return
  fi

  local state
  state="$(review_state_file "$repo")"
  if [ "$verdict" = "return" ]; then
    rm -f "$state"
    return
  fi
  mkdir -p "$(dirname "$state")"
  diff_fingerprint "$repo" >"$state.tmp"
  mv "$state.tmp" "$state"
}

main "$@"
