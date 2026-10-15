review_state_file() {
  local repo="$1"
  local key
  key="$(printf '%s' "$repo" | shasum -a 256 | cut -d ' ' -f 1)"
  printf '%s/verdicts/%s\n' "$CLAUDE_PLUGIN_DATA" "$key"
}

repo_root() {
  (cd "$1" && git rev-parse --show-toplevel 2>/dev/null)
}

diff_base() {
  if git rev-parse --verify --quiet HEAD >/dev/null; then
    printf 'HEAD\n'
    return
  fi
  git hash-object -t tree /dev/null
}

carried_paths() {
  (
    cd "$1" || exit 1
    git diff --name-only --no-renames "$(diff_base)"
    case "$2" in
      added) git ls-files --others --exclude-standard ;;
      tracked_only) ;;
      *)
        printf 'carried_paths: unknown untracked mode %s\n' "$2" >&2
        exit 1
        ;;
    esac
  )
}

code_paths() {
  printf '%s\n' "$1" | grep -v -e '\.md$' -e '^$' || true
}

touches_code() {
  [ -n "$(code_paths "$1")" ]
}

accepted_fingerprint() {
  head -n 1 "$1"
}

accepted_paths() {
  tail -n +2 "$1"
}

working_blob() {
  local repo="$1" path="$2"
  if [ -L "$repo/$path" ]; then
    readlink "$repo/$path" | tr -d '\n' | git -C "$repo" hash-object --stdin
    return
  fi
  git -C "$repo" hash-object -- "$path" 2>/dev/null
}

working_mode() {
  local repo="$1" path="$2"
  if [ -L "$repo/$path" ]; then
    printf '120000\n'
  elif [ -x "$repo/$path" ]; then
    printf '100755\n'
  else
    printf '100644\n'
  fi
}

diff_fingerprint() {
  (
    cd "$1" || exit 1
    local base
    base="$(diff_base)"
    git diff --binary --no-renames --diff-filter=a "$base"
    {
      git diff --name-only --no-renames --diff-filter=A -z "$base"
      git ls-files --others --exclude-standard -z
    } | sort -z | while IFS= read -r -d '' path; do
      printf '%s\0' "$path"
      working_mode . "$path"
      working_blob . "$path"
    done
  ) | shasum -a 256 | cut -d ' ' -f 1
}
