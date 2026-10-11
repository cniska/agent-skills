#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=review-state.sh
source "$HERE/review-state.sh"

readonly MISSING_VERDICT_REASON="End your report with a last line that is exactly 'Verdict: accept' or 'Verdict: return'."

die() {
  printf 'review-record.sh: %s\n' "$1" >&2
  exit 1
}

handback_report() {
  local transcript="$1"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "SubagentHandback") | .input.message // empty' "$transcript"
}

common_dir() {
  (cd "$1" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
}

read_paths() {
  local transcript="$1"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | select(.name == "Read" or .name == "Grep" or .name == "Glob") | .input.file_path // .input.path // empty' "$transcript"
}

reviewed_repos() {
  local transcript="$1" cwd="$2"
  local family
  family="$(common_dir "$cwd")" || return 0
  local path dir root found=""
  while IFS= read -r path; do
    dir="$path"
    [ -d "$dir" ] || dir="$(dirname "$path")"
    [ -d "$dir" ] || continue
    [ "$(common_dir "$dir")" = "$family" ] || continue
    root="$(repo_root "$dir")" || continue
    found="$found$root"$'\n'
  done < <(read_paths "$transcript")
  if [ -z "$found" ]; then
    repo_root "$cwd"
    return
  fi
  printf '%s' "$found" | sort -u
}

verdict_of() {
  grep -Eo '^Verdict: (accept|return)$' | tail -n 1 | cut -d ' ' -f 2 || true
}

main() {
  : "${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is required}"
  jq --version >/dev/null 2>&1 || die "jq is required to read the reviewer's verdict"
  local input cwd transcript last_message stop_hook_active
  input="$(cat)"
  cwd="$(jq -r '.cwd // empty' <<<"$input")"
  transcript="$(jq -r '.agent_transcript_path // empty' <<<"$input")"
  last_message="$(jq -r '.last_assistant_message // empty' <<<"$input")"
  stop_hook_active="$(jq -r '.stop_hook_active // false' <<<"$input")"

  local verdict
  verdict="$(printf '%s\n%s\n' "$(handback_report "$transcript")" "$last_message" | verdict_of)"
  if [ -z "$verdict" ]; then
    if [ "$stop_hook_active" = "true" ]; then
      return
    fi
    jq -cn --arg reason "$MISSING_VERDICT_REASON" '{decision: "block", reason: $reason}'
    return
  fi

  local repo state
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    state="$(review_state_file "$repo")"
    if [ "$verdict" = "return" ]; then
      rm -f "$state"
      continue
    fi
    mkdir -p "$(dirname "$state")"
    diff_fingerprint "$repo" >"$state.tmp"
    mv "$state.tmp" "$state"
  done < <(reviewed_repos "$transcript" "$cwd")
}

main "$@"
