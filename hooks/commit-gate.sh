#!/usr/bin/env bash
set -eEuo pipefail
trap 'gate_failed "$LINENO"' ERR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"
source "$HERE/event-log.sh"
source "$HERE/hook-output.sh"

INPUT=""
COMMIT_PARTS=()
COMMIT_CALLS=()

readonly QUOTES="'\""
readonly WORD_START="(^|[;&|(${QUOTES}]|[[:space:]])"
readonly WORD_END="([[:space:];&|)${QUOTES}]|\$)"
readonly COMMAND_START="(^|[;&|(\`]|"$'\n'")[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*"
readonly GIT_COMMAND="${COMMAND_START}([^[:space:];&|()${QUOTES}]*/)?git"
readonly GIT_OPTIONS="([[:space:]]+(-[Cc]|--git-dir|--work-tree|--namespace)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[^[:space:]]+)*"
readonly GIT_COMMIT_PATTERN="${GIT_COMMAND}${GIT_OPTIONS}[[:space:]]+commit${WORD_END}"
readonly COMMIT_DIR_PATTERN='[[:space:]]-C[[:space:]]+([^[:space:]]+)'
readonly LEADING_CD_PATTERN='^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*(&&|;)'
readonly LEADING_MKTEMP_CD_PATTERN='^([[:space:]]*cd[[:space:]]+)"\$\(mktemp[[:space:]]+-d\)"'
readonly MKTEMP_NAME="tmp.XXXXXXXXXX"
readonly CHAIN_BREAK_PATTERN="[;&|"$'\n'"]"
readonly REPO_OVERRIDE_PATTERN="--git-dir|--work-tree|GIT_DIR=|GIT_WORK_TREE="
readonly REPO_CHANGE_PATTERN="${WORD_START}(cd|pushd)${WORD_END}|[[:space:]]-C[[:space:]]|${REPO_OVERRIDE_PATTERN}"
readonly GIT_SUBCOMMAND="${GIT_COMMAND}${GIT_OPTIONS}[[:space:]]+"
readonly REPO_INIT_PATTERN="${GIT_SUBCOMMAND}init${WORD_END}"
readonly REPO_CLONE_PATTERN="${GIT_SUBCOMMAND}clone${WORD_END}"
readonly REPO_DIR_ARG="${WORD_START}(cd|pushd)[[:space:]]+|[[:space:]]-C[[:space:]]+"
readonly REPO_TARGET_PATTERN="(${REPO_DIR_ARG})[^[:space:];&|)]+"
readonly PLAIN_PATH_PATTERN='^/[A-Za-z0-9_./@+:-]*$'
readonly PARENT_STEP_PATTERN='(^|/)(\.\.|-)(/|$)'
readonly TEMP_ROOTS=(/tmp /private/tmp /var/folders /private/var/folders)
readonly HEREDOC_OPEN="(^|[^<])<<-?[[:space:]]*"
readonly HEREDOC_PATTERN="${HEREDOC_OPEN}[${QUOTES}]?([A-Za-z0-9_.-]+)[${QUOTES}]?(.*)\$"
readonly BACKSLASH="\\"
readonly QUOTE_STARTS="${QUOTES}${BACKSLASH}"
readonly SHELL_CODE="(ba|da|k|z)?sh([[:space:]]+-[A-Za-z]+)*[[:space:]]+-[A-Za-z]*c|eval"
readonly KEPT_QUOTE_PATTERN="(${REPO_DIR_ARG}|${HEREDOC_OPEN}|${WORD_START}(${SHELL_CODE})[[:space:]]+)\$"
readonly SUBSTITUTION_PATTERN='\$\(|`'
readonly HOME_PREFIXES=(\~ "\$HOME" "\${HOME}")
readonly MULTIPLE_REASON="Commit blocked: this command runs more than one git commit, and the reviewer gate checks one commit per command. Run each commit as its own command."
readonly AMBIGUOUS_REASON="Commit blocked: this command reaches its repository in a way the reviewer gate cannot follow, so the verdict for this commit cannot be checked. Commit with 'cd <absolute path> && git commit ...'."
readonly CREATE_REASON="Commit blocked: this command creates the repository it commits to, so no reviewer verdict can cover the commit. Run git init or git clone on its own first, then commit once cniska-skills:reviewer has accepted the diff. A scratch repo passes when the command starts with cd <temp path> && or cd \"\$(mktemp -d)\" && and joins every step with &&."

heredoc_delimiters() {
  local rest="$1"
  while [[ $rest =~ $HEREDOC_PATTERN ]]; do
    printf '%s\n' "${BASH_REMATCH[2]}"
    rest="${BASH_REMATCH[3]}"
  done
}

quote_kept() {
  local before="$1" quote="$2" body="$3"
  if [[ $before =~ $KEPT_QUOTE_PATTERN ]]; then
    return 0
  fi
  [ "$quote" = '"' ] && [[ $body =~ $SUBSTITUTION_PATTERN ]]
}

masked_command() {
  local line delimiter rest plain char stops raw="" out="" quote="" escapes="" body="" line_start=0
  local -a pending=()
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$quote" ] && [ "${#pending[@]}" -gt 0 ]; then
      if [ "${line#"${line%%[!$'\t']*}"}" = "${pending[0]}" ]; then
        pending=("${pending[@]:1}")
      fi
      continue
    fi
    raw+="$line"$'\n'
    rest="$line"
    while [ -n "$rest" ]; do
      if [ -z "$quote" ]; then
        plain="${rest%%["$QUOTE_STARTS"]*}"
        out+="$plain"
        rest="${rest:${#plain}}"
        [ -n "$rest" ] || break
        char="${rest:0:1}"
        rest="${rest:1}"
        if [ "$char" = "$BACKSLASH" ]; then
          out+="$char${rest:0:1}"
          rest="${rest:1}"
          continue
        fi
        quote="$char"
        body=""
        escapes=""
        if [ "$char" = '"' ] || [ "${out: -1}" = '$' ]; then
          escapes=yes
        fi
        continue
      fi
      stops="$quote"
      if [ -n "$escapes" ]; then
        stops="$quote$BACKSLASH"
      fi
      plain="${rest%%["$stops"]*}"
      body+="$plain"
      rest="${rest:${#plain}}"
      [ -n "$rest" ] || break
      char="${rest:0:1}"
      rest="${rest:1}"
      if [ "$char" = "$BACKSLASH" ]; then
        body+="$char${rest:0:1}"
        rest="${rest:1}"
        continue
      fi
      if quote_kept "$out" "$quote" "$body"; then
        out+="$quote$body$quote"
      else
        out+="$quote$quote"
      fi
      quote=""
    done
    if [ -n "$quote" ]; then
      body+=$'\n'
      continue
    fi
    while IFS= read -r delimiter; do
      pending+=("$delimiter")
    done < <(heredoc_delimiters "${out:$line_start}")
    out+=$'\n'
    line_start="${#out}"
  done <<<"$1"
  if [ -n "$quote" ]; then
    printf '%s' "$raw"
    return
  fi
  printf '%s\n' "$out"
}

walk_commits() {
  local rest="$1" call part
  COMMIT_PARTS=()
  COMMIT_CALLS=()
  while [[ $rest =~ $GIT_COMMIT_PATTERN ]]; do
    call="${BASH_REMATCH[0]}"
    part="${rest%%"$call"*}$call"
    COMMIT_PARTS+=("$part")
    COMMIT_CALLS+=("$call")
    rest="${rest#"$part"}"
  done
}

named_dir() {
  local prefix="$1" call="$2"
  if [[ $call =~ $COMMIT_DIR_PATTERN ]]; then
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

repo_targets() {
  { grep -oE "$REPO_TARGET_PATTERN" <<<"$1" || true; } | sed -E "s/^(${REPO_DIR_ARG})//"
}

temp_roots() {
  local root
  for root in ${TMPDIR:+"$TMPDIR"} "${TEMP_ROOTS[@]}"; do
    if [ -d "$root" ]; then
      (cd "$root" && pwd -P)
    fi
  done
}

under_temp() {
  local path="$1" dir root
  [[ $path =~ $PLAIN_PATH_PATTERN ]] || return 1
  ! [[ $path =~ $PARENT_STEP_PATTERN ]] || return 1
  dir="$path"
  while [ ! -d "$dir" ]; do
    dir="$(dirname "$dir")"
  done
  dir="$(cd "$dir" && pwd -P)" || return 1
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    if [ "$dir" = "$root" ] || [[ $dir == "$root"/* ]]; then
      return 0
    fi
  done < <(temp_roots)
  return 1
}

with_leading_temp_dir() {
  local root="${TMPDIR:-/tmp}"
  if ! [ -d "$root" ] || ! [ -w "$root" ]; then
    printf '%s\n' "$1"
    return
  fi
  local command="$1"
  if [[ $command =~ $LEADING_MKTEMP_CD_PATTERN ]]; then
    command="${BASH_REMATCH[1]}\"${root%/}/$MKTEMP_NAME\"${command#"${BASH_REMATCH[0]}"}"
  fi
  printf '%s\n' "$command"
}

only_and_chain() {
  local joined="${1//&&/}"
  ! [[ $joined =~ $CHAIN_BREAK_PATTERN ]]
}

leading_dir() {
  local prefix="$1" cwd="$2" target
  [[ $prefix =~ $LEADING_CD_PATTERN ]] || return 1
  target="${BASH_REMATCH[1]}"
  only_and_chain "$prefix" || return 1
  expanded_dir "$target" "$cwd"
}

every_commit_named() {
  local call
  for call in "${COMMIT_CALLS[@]}"; do
    [[ $call =~ $COMMIT_DIR_PATTERN ]] || return 1
  done
}

scratch_dir() {
  local prefix="$1" cwd="$2" dir
  if under_temp "$cwd"; then
    printf '%s\n' "$cwd"
  elif dir="$(leading_dir "$prefix" "$cwd")" && under_temp "$dir"; then
    printf '%s\n' "$dir"
  elif every_commit_named; then
    printf '%s\n' "$cwd"
  else
    return 1
  fi
}

creates_scratch_repo() {
  local prefix cwd="$2" dir targets target count=0
  prefix="$(with_leading_temp_dir "$1")"
  ! grep -qE -- "$REPO_OVERRIDE_PATTERN" <<<"$prefix" || return 1
  dir="$(scratch_dir "$prefix" "$cwd")" || return 1
  targets="$(repo_targets "$prefix")"
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    count=$((count + 1))
    under_temp "$(expanded_dir "$target" "$dir")" || return 1
  done <<<"$targets"
  [ "$count" -eq "$(repo_changes "$prefix")" ]
}

uncovered_items() {
  awk -F '\t' '
    {
      side = $1 == "staged" ? "staged" : "working tree"
      path = substr($0, length($1) + 2)
      if (path == last) {
        side = "staged and working tree"
      } else if (last != "") {
        print item
      }
      last = path
      item = path " (" side ")"
    }
    END { if (last != "") print item }'
}

uncovered_reason() {
  local items pronoun=it
  items="$(uncovered_items <<<"$1")"
  [ "$(wc -l <<<"$items")" -eq 1 ] || pronoun=them
  printf "Commit blocked: no diff cniska-skills:reviewer accepted covers %s, which this commit can carry. A diff file covers a path's staged or working-tree content only when the review brief names that file by its absolute path, the reviewer reads it, and the diff's new side is that content, and only until a later commit changes the path. An edit this commit is not meant to carry can be set aside with git stash, or git stash -u for an untracked file, and restored after the commit without voiding any accept. Otherwise write the current diff of %s to a new file and brief a fresh reviewer naming that file by its absolute path, then commit once it ends with 'Verdict: accept'." "$(awk 'NR > 1 { printf ", " } { printf "%s", $0 }' <<<"$items")" "$pronoun"
}

unresolved_reason() {
  printf 'Commit blocked: %s is not a repository, so the reviewer verdict for this commit cannot be checked. Name the repository by an absolute path in cd.' "$1"
}

record() {
  event_log "$INPUT" gate --arg gate commit --arg decision "$1" --arg reason "$2" \
    --arg repo "${3:-}" --arg head "${4:-}" --arg fingerprint "${5:-}"
}

gate_failed() {
  local status=$?
  if [ "$BASH_SUBSHELL" -gt 0 ]; then
    exit "$status"
  fi
  trap - ERR
  printf 'commit-gate.sh failed on line %s, so the commit is refused until the gate runs cleanly\n' "$1" >&2
  record deny gate_error
  exit 2
}

deny() {
  record deny "$2" "${3:-}" "${4:-}" "${5:-}"
  pre_tool_deny "$1"
}

honoured() {
  local repo="$1" since="$2" path="$3" range=HEAD touched
  if [ "$since" != - ]; then
    git -C "$repo" merge-base --is-ancestor "$since" HEAD 2>/dev/null || return 1
    range="$since..HEAD"
  elif ! git -C "$repo" rev-parse --verify --quiet HEAD >/dev/null; then
    return 0
  fi
  touched="$(git --literal-pathspecs -C "$repo" rev-list -1 "$range" -- "$path")" || return 1
  [ -z "$touched" ]
}

covered() {
  local repo="$1" state="$2" content="$3" path="$4" since
  while IFS= read -r since; do
    ! honoured "$repo" "$since" "$path" || return 0
  done < <(accepted_heads "$state" "$content" "$path")
  return 1
}

uncovered_sides() {
  local repo="$1" state="$2" side content path
  while IFS=$'\t' read -r side content path; do
    covered "$repo" "$state" "$content" "$path" || printf '%s\t%s\n' "$side" "$path"
  done <<<"$3"
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
  command="$(masked_command "$(jq -r '.tool_input.command // empty' <<<"$INPUT")")"
  cwd="$(jq -r '.cwd // empty' <<<"$INPUT")"
  if ! [[ $command =~ $GIT_COMMIT_PATTERN ]]; then
    return
  fi

  local prefix span named changes repo
  walk_commits "$command"
  prefix="${COMMIT_PARTS[0]}"
  if [[ $prefix =~ $REPO_CLONE_PATTERN || $prefix =~ $REPO_INIT_PATTERN ]]; then
    span="$(printf '%s' "${COMMIT_PARTS[@]}")"
    if creates_scratch_repo "$span" "$cwd"; then
      record allow scratch_repo
    else
      deny "$CREATE_REASON" repo_created
    fi
    return
  fi
  if [ "${#COMMIT_CALLS[@]}" -gt 1 ]; then
    deny "$MULTIPLE_REASON" multiple_commits
    return
  fi
  named="$(named_dir "$prefix" "${COMMIT_CALLS[0]}")"
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
  local head code sides fingerprint
  head="$(head_commit "$repo")"
  code="$(code_paths "$repo" "$(judged_paths "$repo")")"
  sides=""
  [ -z "$code" ] || sides="$(judged_sides "$repo" "$code")"
  if [ -z "$sides" ]; then
    record allow no_code_change "$repo" "$head"
    return
  fi
  fingerprint="$(set_fingerprint <<<"$sides")"

  local state uncovered reason=outside_accept
  state="$(review_state_file "$repo")"
  if [ ! -s "$state" ]; then
    deny "$(uncovered_reason "$(cut -f 1,3- <<<"$sides")")" not_accepted "$repo" "$head" "$fingerprint"
    return
  fi
  uncovered="$(uncovered_sides "$repo" "$state" "$sides")"
  if [ -z "$uncovered" ]; then
    record allow accepted "$repo" "$head" "$fingerprint"
    return
  fi
  if accepted_any "$state" "$(cut -f 2- <<<"$uncovered")"; then
    reason=changed_since_accept
  fi
  deny "$(uncovered_reason "$uncovered")" "$reason" "$repo" "$head" "$fingerprint"
}

main "$@"
