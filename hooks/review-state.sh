MISSING_MODE=000000
MISSING_BLOB=0

fresh_reviewer_step() {
  printf '%s' "Start a fresh cniska-skills:reviewer on the fix's diff, with the change's earlier diff files to read as context"
}

data_key() {
  printf '%s' "$1" | shasum -a 256 | cut -d ' ' -f 1
}

review_state_file() {
  local key
  key="$(data_key "$1")"
  printf '%s/verdicts/%s\n' "$CLAUDE_PLUGIN_DATA" "$key"
}

reviewer_marker() {
  local key
  key="$(data_key "$1")"
  printf '%s/reviewers/%s\n' "$CLAUDE_PLUGIN_DATA" "$key"
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

judged_paths() {
  local repo="$1" base
  base="$(cd "$repo" && diff_base)"
  {
    git -C "$repo" diff --cached --name-only --no-renames -z "$base"
    git -C "$repo" diff --name-only --no-renames -z "$base"
    git -C "$repo" ls-files --others --exclude-standard -z
  } | tr '\0' '\n' | sort -u
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

tree_content() {
  local repo="$1" tree="$2" path="$3" mode="" blob=""
  read -r mode _ blob _ < <(git --literal-pathspecs -C "$repo" ls-tree "$tree" -- "$path") || true
  printf '%s %s\n' "${mode:-$MISSING_MODE}" "${blob:-$MISSING_BLOB}"
}

index_content() {
  local repo="$1" path="$2" mode="" blob=""
  read -r mode blob _ < <(git --literal-pathspecs -C "$repo" ls-files -s -- "$path") || true
  printf '%s %s\n' "${mode:-$MISSING_MODE}" "${blob:-$MISSING_BLOB}"
}

worktree_content() {
  local repo="$1" path="$2"
  if [ ! -e "$repo/$path" ] && [ ! -L "$repo/$path" ]; then
    printf '%s %s\n' "$MISSING_MODE" "$MISSING_BLOB"
    return
  fi
  printf '%s %s\n' "$(working_mode "$repo" "$path")" "$(working_blob "$repo" "$path")"
}

judged_sides() {
  local repo="$1" base path head staged working
  base="$(cd "$repo" && diff_base)"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    head="$(tree_content "$repo" "$base" "$path")"
    staged="$(index_content "$repo" "$path")"
    working="$(worktree_content "$repo" "$path")"
    [ "$staged" = "$head" ] || printf '%s\t%s\t%s\n' staged "$staged" "$path"
    [ "$working" = "$head" ] || printf '%s\t%s\t%s\n' working "$working" "$path"
  done <<<"$2"
}

set_fingerprint() {
  sort | shasum -a 256 | cut -d ' ' -f 1
}

accept_entries() {
  awk -v head="$1" 'NF { print head "\t" $0 }'
}

path_entries() {
  awk -F '\t' 'NR == FNR { wanted[$0]; next } substr($0, length($1) + length($2) + 3) in wanted { print $1 "\t" $2 }' - "$1"
}

accepted_heads() {
  path_entries "$1" <<<"$3" | CONTENT="$2" awk -F '\t' '$2 == ENVIRON["CONTENT"] { print $1 }'
}

accepted_any() {
  [ -n "$(path_entries "$1" <<<"$2")" ]
}
