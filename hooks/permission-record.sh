#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/event-log.sh"

readonly RULE_PATTERN='^\[([^]]+)\]$'
readonly UNEVALUATED_PREFIX='Auto mode could not evaluate'
readonly CLASSIFIER_UNAVAILABLE='Classifier unavailable'

field() {
  jq -r "$1 // empty" <<<"$2" 2>/dev/null
}

record_denial() {
  local input="$1" tool="$2" text code=other rule=""
  text="$(field .reason "$input")"
  if [[ $text =~ $RULE_PATTERN ]]; then
    code=rule
    rule="${BASH_REMATCH[1]}"
  elif [[ $text == "$UNEVALUATED_PREFIX"* ]]; then
    code=unevaluated
  elif [ "$text" = "$CLASSIFIER_UNAVAILABLE" ]; then
    code=classifier_unavailable
  fi
  event_log "$input" permission_denied --arg tool "$tool" --arg tool_use "$(field .tool_use_id "$input")" \
    --arg reason "$code" --arg rule "$rule"
}

main() {
  local input tool
  input="$(cat)"
  tool="$(field .tool_name "$input")"
  case "$(field .hook_event_name "$input")" in
    PermissionRequest) event_log "$input" permission_prompt --arg tool "$tool" ;;
    PermissionDenied) record_denial "$input" "$tool" ;;
    *) printf 'permission-record.sh: expected a PermissionRequest or PermissionDenied event\n' >&2 ;;
  esac
  return 0
}

main "$@"
