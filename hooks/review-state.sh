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

touches_code() {
  printf '%s' "$1" | grep -v '\.md$' >/dev/null
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
      git hash-object -- "$path"
    done
  ) | shasum -a 256 | cut -d ' ' -f 1
}
