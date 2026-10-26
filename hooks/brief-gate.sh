#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/hook-output.sh"
source "$HERE/paths.sh"

readonly REVIEWER=cniska-skills:reviewer
readonly BARE_FILE='^[^/](.*[^/])?\.(diff|log)$'
readonly GIT_READ='\bgit\s+(?:show|-C|diff)\b|\bgit\s+log\b[^\n`;|&,()]*?\s(?:-p|--patch)\b'
readonly NO_SHELL="Reviewer brief refused: $REVIEWER has no shell, so it reads only files named by absolute path."

bare_files() {
  jq -r '.tool_input.prompt // ""' <<<"$1" | path_tokens | { grep -E "$BARE_FILE" || [ "$?" -eq 1 ]; } | LC_ALL=C sort -u | paste -sd , - | sed 's/,/, /g'
}

git_reads() {
  jq -r --arg git "$GIT_READ" '[.tool_input.prompt // "" | scan($git)] | unique | join(", ")' <<<"$1"
}

refusal() {
  local files="$1" reads="$2" reason="$NO_SHELL"
  [ -z "$files" ] || reason+=" Name each diff or log file by its absolute path: $files."
  [ -z "$reads" ] || reason+=" It cannot run $reads: write each command's output to a file in your temp folder and name the file by its absolute path."
  printf '%s\n' "$reason"
}

main() {
  local input type files reads
  input="$(cat)"
  if ! type="$(jq -r '.tool_input.subagent_type // empty' <<<"$input" 2>/dev/null)"; then
    printf 'brief-gate.sh: allowed the agent start unchecked: its input is not JSON\n' >&2
    return 0
  fi
  [ "$type" = "$REVIEWER" ] || return 0
  if ! files="$(bare_files "$input")" || ! reads="$(git_reads "$input")"; then
    printf 'brief-gate.sh: allowed the reviewer start unchecked: its prompt could not be read\n' >&2
    return 0
  fi
  [ -n "$files$reads" ] || return 0
  pre_tool_deny "$(refusal "$files" "$reads")"
}

main "$@"
