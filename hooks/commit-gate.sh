#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=review-state.sh
source "$HERE/review-state.sh"

readonly GIT_COMMIT_PATTERN='(^|[;&|(]|[[:space:]])([^[:space:];&|()]*/)?git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
readonly GIT_DIR_PATTERN='git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]+commit'
readonly LEADING_CD_PATTERN='^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*&&'
readonly DENY_REASON="Commit blocked: cniska-skills:reviewer has not accepted this diff. Hand the change to cniska-skills:reviewer and commit once it ends with 'Verdict: accept', with no edits since."

commit_dir() {
  local command="$1" cwd="$2" target=""
  if [[ $command =~ $GIT_DIR_PATTERN ]]; then
    target="${BASH_REMATCH[1]}"
  elif [[ $command =~ $LEADING_CD_PATTERN ]]; then
    target="${BASH_REMATCH[1]}"
  fi
  case "$target" in
    "") printf '%s\n' "$cwd" ;;
    /*) printf '%s\n' "$target" ;;
    *) printf '%s/%s\n' "$cwd" "$target" ;;
  esac
}

deny() {
  jq -cn --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
}

main() {
  if ! jq --version >/dev/null 2>&1; then
    printf 'commit-gate.sh: jq is required to check commits against the reviewer verdict\n' >&2
    exit 2
  fi
  : "${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is required}"
  local input command cwd
  input="$(cat)"
  command="$(jq -r '.tool_input.command // empty' <<<"$input")"
  cwd="$(jq -r '.cwd // empty' <<<"$input")"
  if ! grep -Eq "$GIT_COMMIT_PATTERN" <<<"$command"; then
    return
  fi

  local repo
  repo="$(repo_root "$(commit_dir "$command" "$cwd")")" || return 0
  [ -n "$repo" ] || return 0
  if ! touches_code "$repo"; then
    return
  fi

  local state
  state="$(review_state_file "$repo")"
  if [ -f "$state" ] && [ "$(cat "$state")" = "$(diff_fingerprint "$repo")" ]; then
    return
  fi
  deny "$DENY_REASON"
}

main "$@"
