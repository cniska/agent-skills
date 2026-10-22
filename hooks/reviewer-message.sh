#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"
source "$HERE/hook-output.sh"

REVIEWED_REASON="This agent gave a review verdict, and a message to it resumes the same reviewer rather than starting a fresh review. $(fresh_reviewer_step)."
readonly REVIEWED_REASON

allow_unchecked() {
  printf 'reviewer-message.sh: allowed the message unchecked: %s\n' "$1" >&2
  exit 0
}

main() {
  jq --version >/dev/null 2>&1 || allow_unchecked "jq is required to read the recipient"
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] || allow_unchecked "CLAUDE_PLUGIN_DATA is required to find recorded verdicts"
  local input recipient
  input="$(cat)"
  recipient="$(jq -r '.tool_input.to // empty' <<<"$input" 2>/dev/null)" || allow_unchecked "the hook input is not JSON"
  recipient="${recipient% \[*\]}"
  [ -n "$recipient" ] && [ -f "$(reviewer_marker "$recipient")" ] || return 0
  pre_tool_deny "$REVIEWED_REASON"
}

main "$@"
