#!/usr/bin/env bash
set -eEuo pipefail
trap 'gate_failed "$LINENO"' ERR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"
source "$HERE/event-log.sh"

INPUT=""

readonly QUOTES="'\""
readonly WORD_START="(^|[;&|(${QUOTES}]|[[:space:]])"
readonly WORD_END="([[:space:];&|)${QUOTES}]|\$)"
readonly COMMAND_START="(^|[;&|(]|"$'\n'")[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*"
readonly GIT_COMMAND="${COMMAND_START}([^[:space:];&|()${QUOTES}]*/)?git"
readonly GIT_COMMIT_PATTERN="${GIT_COMMAND}([[:space:]]+(-[Cc]|--git-dir|--work-tree|--namespace)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[^[:space:]]+)*[[:space:]]+commit${WORD_END}"
readonly GIT_DIR_PATTERN='git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]+commit'
readonly LEADING_CD_PATTERN='^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*(&&|;)'
readonly REPO_CHANGE_PATTERN="${WORD_START}(cd|pushd)${WORD_END}|[[:space:]]-C[[:space:]]|--git-dir|--work-tree|GIT_DIR=|GIT_WORK_TREE="
readonly REPO_CREATE_PATTERN="${GIT_COMMAND}([[:space:]]+-[^[:space:]]+)*[[:space:]]+(init|clone)${WORD_END}"
readonly HEREDOC_PATTERN="(^|[^<])<<-?[[:space:]]*[${QUOTES}]?([A-Za-z0-9_.-]+)[${QUOTES}]?(.*)\$"
readonly HOME_PREFIXES=(\~ "\$HOME" "\${HOME}")
readonly DENY_REASON="Commit blocked: cniska-skills:reviewer has not accepted this diff. Hand the change to cniska-skills:reviewer with the absolute path of its repo and commit once it ends with 'Verdict: accept', with no edits since."
readonly MULTIPLE_REASON="Commit blocked: this command runs more than one git commit, and the reviewer gate checks one commit per command. Run each commit as its own command."
readonly AMBIGUOUS_REASON="Commit blocked: this command reaches its repository in a way the reviewer gate cannot follow, so the verdict for this commit cannot be checked. Commit with 'cd <absolute path> && git commit ...'."
readonly CREATE_REASON="Commit blocked: this command creates the repository it commits to, so no reviewer verdict can cover the commit. Run git init or git clone on its own first, then commit once cniska-skills:reviewer has accepted the diff."

heredoc_delimiters() {
  local rest="$1"
  while [[ $rest =~ $HEREDOC_PATTERN ]]; do
    printf '%s\n' "${BASH_REMATCH[2]}"
    rest="${BASH_REMATCH[3]}"
  done
}

without_heredocs() {
  local line delimiter
  local -a pending=()
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "${#pending[@]}" -gt 0 ]; then
      if [ "${line#"${line%%[!$'\t']*}"}" = "${pending[0]}" ]; then
        pending=("${pending[@]:1}")
      fi
      continue
    fi
    printf '%s\n' "$line"
    while IFS= read -r delimiter; do
      pending+=("$delimiter")
    done < <(heredoc_delimiters "$line")
  done <<<"$1"
}

commit_command() {
  local command="$1"
  [[ $command =~ $GIT_COMMIT_PATTERN ]]
  local match="${BASH_REMATCH[0]}"
  printf '%s%s\n' "${command%%"$match"*}" "$match"
}

named_dir() {
  local prefix="$1"
  if [[ $prefix =~ $GIT_DIR_PATTERN ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  elif [[ $prefix =~ $LEADING_CD_PATTERN ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

repo_changes() {
  { grep -oE "$REPO_CHANGE_PATTERN" <<<"$1" || true; } | wc -l | tr -d ' '
}

unquoted() {
  local target="$1" quote
  for quote in '"' "'"; do
    if [[ ${#target} -ge 2 && $target == "$quote"*"$quote" ]]; then
      target="${target:1:${#target}-2}"
      break
    fi
  done
  printf '%s\n' "$target"
}

expanded_dir() {
  local target cwd="$2" prefix
  target="$(unquoted "$1")"
  for prefix in "${HOME_PREFIXES[@]}"; do
    if [ "$target" = "$prefix" ]; then
      target="$HOME"
    elif [[ $target == "$prefix"/* ]]; then
      target="$HOME/${target#"$prefix"/}"
    fi
  done
  case "$target" in
    /*) printf '%s\n' "$target" ;;
    *) printf '%s/%s\n' "$cwd" "$target" ;;
  esac
}

unresolved_reason() {
  printf 'Commit blocked: %s is not a repository, so the reviewer verdict for this commit cannot be checked. Name the repository by an absolute path in cd.' "$1"
}

record() {
  event_log "$INPUT" gate --arg gate commit --arg decision "$1" --arg reason "$2" \
    --arg repo "${3:-}" --arg head "${4:-}" --arg fingerprint "${5:-}"
}

gate_failed() {
  trap - ERR
  printf 'commit-gate.sh failed on line %s, so the commit is refused until the gate runs cleanly\n' "$1" >&2
  if [ "$BASH_SUBSHELL" -eq 0 ]; then
    record deny gate_error
  fi
  exit 2
}

deny() {
  record deny "$2" "${3:-}" "${4:-}" "${5:-}"
  jq -cn --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
}

head_commit() {
  git -C "$1" rev-parse --verify --quiet HEAD || true
}

main() {
  if ! jq --version >/dev/null 2>&1; then
    printf 'commit-gate.sh: jq is required to check commits against the reviewer verdict\n' >&2
    exit 2
  fi
  : "${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is required}"
  local command cwd
  INPUT="$(cat)"
  command="$(without_heredocs "$(jq -r '.tool_input.command // empty' <<<"$INPUT")")"
  cwd="$(jq -r '.cwd // empty' <<<"$INPUT")"
  if ! [[ $command =~ $GIT_COMMIT_PATTERN ]]; then
    return
  fi

  local prefix named changes repo
  prefix="$(commit_command "$command")"
  if [[ ${command#"$prefix"} =~ $GIT_COMMIT_PATTERN ]]; then
    deny "$MULTIPLE_REASON" multiple_commits
    return
  fi
  if [[ $prefix =~ $REPO_CREATE_PATTERN ]]; then
    deny "$CREATE_REASON" repo_created
    return
  fi
  named="$(named_dir "$prefix")"
  changes="$(repo_changes "$prefix")"
  if [ "$changes" -eq 0 ]; then
    if ! repo="$(repo_root "$cwd")" || [ -z "$repo" ]; then
      record allow outside_repo
      return
    fi
  elif [ "$changes" -gt 1 ] || [ -z "$named" ]; then
    deny "$AMBIGUOUS_REASON" repo_unclear
    return
  elif ! repo="$(repo_root "$(expanded_dir "$named" "$cwd")")" || [ -z "$repo" ]; then
    deny "$(unresolved_reason "$named")" repo_not_found
    return
  fi
  local head
  head="$(head_commit "$repo")"
  if ! touches_code "$repo"; then
    record allow no_code_change "$repo" "$head"
    return
  fi

  local state fingerprint
  state="$(review_state_file "$repo")"
  fingerprint="$(diff_fingerprint "$repo")"
  if [ ! -f "$state" ]; then
    deny "$DENY_REASON" not_accepted "$repo" "$head" "$fingerprint"
  elif [ "$(cat "$state")" = "$fingerprint" ]; then
    record allow accepted "$repo" "$head" "$fingerprint"
  else
    deny "$DENY_REASON" changed_since_accept "$repo" "$head" "$fingerprint"
  fi
}

main "$@"
