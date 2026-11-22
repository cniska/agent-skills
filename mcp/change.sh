readonly CHANGE_BASES='origin/HEAD origin/main'

repo_git() {
  local repo="$1"
  shift
  git -c core.fsmonitor= -C "$repo" "$@"
}

change_base() {
  local repo="$1" ref
  for ref in $CHANGE_BASES; do
    repo_git "$repo" rev-parse --verify --quiet "$ref^{commit}" >/dev/null || continue
    repo_git "$repo" merge-base HEAD "$ref" 2>/dev/null || step_failed "git merge-base HEAD $ref" "$repo" || return 1
    return
  done
  printf '%s has no %s to diff its branch against.\n' "$repo" "${CHANGE_BASES// / or }"
  return 1
}

step_failed() {
  local action="$1" repo="$2"
  shift 2
  rm -f "$@"
  printf '%s failed in %s, so no change was written.\n' "$action" "$repo"
  return 1
}

keep_change_file() {
  local scratch="$1" extension="$2" sha file
  sha="$(shasum -a 256 "$scratch" | cut -d ' ' -f 1)" || step_failed "shasum" "$scratch" "$scratch" || return 1
  file="$CLAUDE_PLUGIN_DATA/changes/$sha.$extension"
  mv "$scratch" "$file" || step_failed "mv" "$scratch" "$scratch" || return 1
  printf '%s\n' "$file"
}

change_files() {
  local repo="$1" kind="$2" dir="$CLAUDE_PLUGIN_DATA/changes" base diff log=""
  mkdir -p "$dir" || {
    printf 'The change cannot be written: %s cannot be created.\n' "$dir"
    return 1
  }
  diff="$(mktemp "$dir/diff.XXXXXX")" || step_failed "mktemp" "$dir" || return 1
  if [ "$kind" = commit ]; then
    repo_git "$repo" diff --cached --no-color --no-ext-diff --no-textconv >"$diff" || step_failed "git diff --cached" "$repo" "$diff" || return 1
    if [ ! -s "$diff" ]; then
      rm -f "$diff"
      printf 'Nothing is staged in %s, so a commit there has no change to judge.\n' "$repo"
      return 1
    fi
  else
    if ! base="$(change_base "$repo")"; then
      rm -f "$diff"
      printf '%s\n' "$base"
      return 1
    fi
    repo_git "$repo" diff --cached --no-color --no-ext-diff --no-textconv "$base" >"$diff" || step_failed "git diff --cached <base>" "$repo" "$diff" || return 1
    if [ ! -s "$diff" ]; then
      rm -f "$diff"
      printf 'The branch in %s holds no change from its base %s.\n' "$repo" "$base"
      return 1
    fi
    log="$(mktemp "$dir/log.XXXXXX")" || step_failed "mktemp" "$dir" "$diff" || return 1
    repo_git "$repo" log --no-color "$base..HEAD" >"$log" || step_failed "git log <base>..HEAD" "$repo" "$log" "$diff" || return 1
    log="$(keep_change_file "$log" log)" || {
      rm -f "$diff"
      printf '%s\n' "$log"
      return 1
    }
  fi
  diff="$(keep_change_file "$diff" diff)" || {
    printf '%s\n' "$diff"
    return 1
  }
  jq -cn --arg repo "$repo" --arg kind "$kind" --arg diff "$diff" --arg log "$log" \
    '{repo: $repo, kind: $kind, diff: $diff, log: (if $log == "" then null else $log end)}'
}

write_change() {
  local repo="$1" kind="$2" dir="$1" top
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    printf 'No change can be written: CLAUDE_PLUGIN_DATA is not set for the report server.\n'
    return 1
  fi
  while [ ! -d "$dir" ]; do
    dir="$(dirname "$dir")"
  done
  if ! top="$(repo_git "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s is not in a git repository. Give the worktree the brief names.\n' "$repo"
    return 1
  fi
  change_files "$top" "$kind"
}
