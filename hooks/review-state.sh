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
  case "$2" in
    added | tracked_only) ;;
    *)
      printf 'carried_paths: unknown untracked mode %s\n' "$2" >&2
      return 1
      ;;
  esac
  (
    cd "$1" || exit 1
    git diff --name-only --no-renames -z "$(diff_base)"
    [ "$2" = tracked_only ] || git ls-files --others --exclude-standard -z
  ) | tr '\0' '\n'
}

local_attributes_set() {
  local common status=0
  common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  [ -e "$common/info/attributes" ] || return 1
  grep -qvE '^[[:space:]]*(#|$)' "$common/info/attributes" 2>/dev/null || status=$?
  [ "$status" -ne 1 ]
}

head_generated_paths() {
  local repo="$1" candidates="$2" lines path _ value count=0
  local -a generated
  generated=()
  ! local_attributes_set "$repo" || return 0
  lines="$(printf '%s\n' "$candidates" | tr '\n' '\0' |
    GIT_ATTR_NOSYSTEM=1 git -C "$repo" -c core.attributesFile=/dev/null check-attr --source=HEAD -z --stdin linguist-generated 2>/dev/null |
    tr '\0' '\n')" || return 0
  while IFS= read -r path && IFS= read -r _ && IFS= read -r value; do
    count=$((count + 1))
    case "$path" in
      .gitattributes | */.gitattributes) continue ;;
    esac
    case "$value" in
      set | true) generated+=("$path") ;;
    esac
  done <<<"$lines"
  [ "$count" -eq "$(wc -l <<<"$candidates")" ] || return 0
  printf '%s\n' ${generated[@]+"${generated[@]}"}
}

code_paths() {
  local repo="$1" candidates generated
  candidates="$(printf '%s\n' "$2" | grep -v -e '\.md$' -e '^$')" || return 0
  generated="$(head_generated_paths "$repo" "$candidates")" || generated=""
  if [ -z "$generated" ]; then
    printf '%s\n' "$candidates"
    return
  fi
  grep -vxF -f <(printf '%s\n' "$generated") <<<"$candidates" || true
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
