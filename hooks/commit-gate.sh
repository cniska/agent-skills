#!/usr/bin/env bash
set -eEuo pipefail
trap 'printf "commit-gate.sh failed on line %s, so the commit is refused until the gate runs cleanly\n" "$LINENO" >&2; exit 2' ERR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"

readonly QUOTES="'\""
readonly WORD_START="(^|[;&|(${QUOTES}]|[[:space:]])"
readonly WORD_END="([[:space:];&|)${QUOTES}]|\$)"
readonly GIT_WORD="${WORD_START}([^[:space:];&|()${QUOTES}]*/)?git"
readonly GIT_COMMIT_PATTERN="${GIT_WORD}([[:space:]]+(-[Cc]|--git-dir|--work-tree|--namespace)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[^[:space:]]+)*[[:space:]]+commit${WORD_END}"
readonly GIT_DIR_PATTERN='git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]+commit'
readonly LEADING_CD_PATTERN='^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*(&&|;)'
readonly REPO_CHANGE_PATTERN="${WORD_START}(cd|pushd)${WORD_END}|[[:space:]]-C[[:space:]]|--git-dir|--work-tree|GIT_DIR=|GIT_WORK_TREE="
readonly REPO_CREATE_PATTERN="${GIT_WORD}([[:space:]]+-[^[:space:]]+)*[[:space:]]+(init|clone)${WORD_END}"
readonly HOME_PREFIXES=(\~ "\$HOME" "\${HOME}")
readonly DENY_REASON="Commit blocked: cniska-skills:reviewer has not accepted this diff. Hand the change to cniska-skills:reviewer with the absolute path of its repo and commit once it ends with 'Verdict: accept', with no edits since."
readonly MULTIPLE_REASON="Commit blocked: this command runs more than one git commit, and the reviewer gate checks one commit per command. Run each commit as its own command."
readonly AMBIGUOUS_REASON="Commit blocked: this command reaches its repository in a way the reviewer gate cannot follow, so the verdict for this commit cannot be checked. Commit with 'cd <absolute path> && git commit ...'."
readonly CREATE_REASON="Commit blocked: this command creates the repository it commits to, so no reviewer verdict can cover the commit. Run git init or git clone on its own first, then commit once cniska-skills:reviewer has accepted the diff."

commit_head() {
  local command="$1"
  [[ $command =~ $GIT_COMMIT_PATTERN ]]
  local match="${BASH_REMATCH[0]}"
  printf '%s%s\n' "${command%%"$match"*}" "$match"
}

named_dir() {
  local head="$1"
  if [[ $head =~ $GIT_DIR_PATTERN ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  elif [[ $head =~ $LEADING_CD_PATTERN ]]; then
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

  local head named changes repo
  head="$(commit_head "$command")"
  if grep -Eq "$GIT_COMMIT_PATTERN" <<<"${command#"$head"}"; then
    deny "$MULTIPLE_REASON"
    return
  fi
  if grep -Eq "$REPO_CREATE_PATTERN" <<<"$head"; then
    deny "$CREATE_REASON"
    return
  fi
  named="$(named_dir "$head")"
  changes="$(repo_changes "$head")"
  if [ "$changes" -eq 0 ]; then
    repo="$(repo_root "$cwd")" || return 0
    [ -n "$repo" ] || return 0
  elif [ "$changes" -gt 1 ] || [ -z "$named" ]; then
    deny "$AMBIGUOUS_REASON"
    return
  elif ! repo="$(repo_root "$(expanded_dir "$named" "$cwd")")" || [ -z "$repo" ]; then
    deny "$(unresolved_reason "$named")"
    return
  fi
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
