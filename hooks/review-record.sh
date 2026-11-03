readonly WORKTREE_MISMATCH_REASON="Name the worktree the change is in as the judgment's repo, not another checkout of its repository."
readonly REPO_REPEATED_REASON="Give each repository one judgment."
readonly ACCEPT_WITH_FINDINGS_REASON="An accept has no findings: while a finding stands, the judgment's verdict is return. A defect that was there before the change and does not block it goes under follow_ups."
SAME_REVIEWER_FIX="This accept is not recorded: its reviewer returned this repository's change earlier. $(fresh_reviewer_step)."
readonly SAME_REVIEWER_FIX
readonly STALE_DIFF_FIX="The diff no longer matches the change, most likely because the change was edited after the diff was written. Write a fresh diff of the change and brief a fresh reviewer with it."
readonly MAX_COUNT=1000

verdict_counts() {
  jq -c --argjson max "$MAX_COUNT" '
    ({critical: 0, major: 0, minor: 0, fix: 0, consider: 0, unrated: 0}
      + (.findings | group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries)) as $findings
    | {findings: $findings, conflicts: (.conflicts | length), follow_ups: (.follow_ups | length), rules: [.findings[].rule]}
    | if ([.findings[], .conflicts, .follow_ups] | max) > $max then {findings: null, conflicts: null, follow_ups: null, rules: null} else . end'
}

location_paths() {
  jq -r '((.findings + .conflicts + .follow_ups)[].where[], .clean[].places[]) | .path'
}

cited_worktrees() {
  local repo="$1" worktrees main_checkout common path dir
  worktrees="$(git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p')"
  main_checkout="$(head -n 1 <<<"$worktrees")"
  [ "$main_checkout" != "$repo" ] || main_checkout=""
  common="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)"
  common="$(cd "$common" && pwd -P)"
  sort -u | while IFS= read -r path; do
    dir="$path"
    while [ ! -d "$dir" ]; do
      dir="$(dirname "$dir")"
    done
    dir="$(cd "$dir" && pwd -P)" || continue
    case "$dir/" in "$common"/*) continue ;; esac
    awk -v dir="$dir/" -v main_checkout="$main_checkout" 'index(dir, $0 "/") == 1 && length($0) > length(best) {best = $0} END {if (best != "" && best != main_checkout) print best}' <<<"$worktrees"
  done | sort -u
}

diff_paths() {
  awk '
    function flush() {
      if (path != "" && from != "") print path "\t@" from "\t" mode
      else if (path != "" && mode != "") print path "\t@" path "\t" mode
      path = ""
      from = ""
      mode = ""
    }
    /^diff --git a\// {
      flush()
      rest = substr($0, 14)
      half = (length(rest) - 3) / 2
      if (half == int(half) && substr(rest, half + 1, 3) == " b/" && substr(rest, half + 4) == substr(rest, 1, half)) path = substr(rest, 1, half)
      next
    }
    /^diff --git "a\// {
      flush()
      rest = substr($0, 12)
      half = (length(rest) - 9) / 2
      if (half == int(half) && half > 0 && substr(rest, half + 4, 5) == "\" \"b/" && substr(rest, half + 9, half) == substr(rest, 4, half) && substr(rest, length(rest)) == "\"") path = "\"" substr(rest, 4, half) "\""
      next
    }
    /^rename from / { from = substr($0, 13); print from "\t0"; next }
    /^copy from / { from = substr($0, 11); next }
    /^(rename|copy) to / { sub(/^(rename|copy) to /, ""); path = $0; next }
    /^new (file )?mode [0-7]+$/ { mode = $NF; next }
    path != "" && /^index [0-9a-f]+\.\.[0-9a-f]+/ {
      split($2, ids, /\.\./)
      print path "\t" ids[2] "\t" (NF > 2 ? $3 : mode)
      path = ""
      from = ""
      mode = ""
    }
    END { flush() }'
}

diff_files_paths() {
  local file
  while IFS= read -r file; do
    [ ! -f "$file" ] || diff_paths <"$file"
  done | sort -u
}

unquote_path() {
  local path="$1"
  if [[ $path != \"*\" ]]; then
    printf '%s\n' "$path"
    return
  fi
  path="${path:1:${#path}-2}"
  printf '%b\n' "$(printf '%s\n' "$path" | awk '{
    out = ""
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      next_char = substr($0, i + 1, 1)
      if (c != "\\") out = out c
      else if (next_char ~ /[0-7]/) { out = out "\\0" substr($0, i + 1, 3); i += 3 }
      else if (next_char == "\"") { out = out "\""; i++ }
      else { out = out "\\" next_char; i++ }
    }
    print out
  }')"
}

current_entries() {
  local repo="$1" path post mode content head_entry_mode
  while IFS=$'\t' read -r path post mode; do
    [ -n "$path" ] || continue
    path="$(unquote_path "$path")"
    if [[ $post == @* ]]; then
      read -r head_entry_mode _ post _ < <(git --literal-pathspecs -C "$repo" ls-tree HEAD -- "$(unquote_path "${post#@}")") || true
      [ -n "$post" ] || continue
      [ -n "$mode" ] || mode="$head_entry_mode"
    fi
    for content in "$(index_content "$repo" "$path")" "$(worktree_content "$repo" "$path")"; do
      if [[ $post =~ ^0+$ ]]; then
        [ "$content" != "$MISSING_MODE $MISSING_BLOB" ] || printf '%s\t%s\n' "$content" "$path"
      elif [[ $content == "$mode $post"* ]]; then
        printf '%s\t%s\n' "$content" "$path"
      fi
    done
  done
}

staged_worktree() {
  local repo="$1" reviewed="$2" worktree
  git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p' | while IFS= read -r worktree; do
    [ "$worktree" != "$repo" ] && [ -d "$worktree" ] || continue
    if [ -n "$(current_entries "$worktree" <<<"$reviewed")" ]; then
      printf '%s\n' "$worktree"
      return
    fi
  done
}

covers_nothing_reason() {
  local repo="$1" reviewed="$2" worktree="$3" path names
  names="$(cut -f 1 <<<"$reviewed" | while IFS= read -r path; do unquote_path "$path"; done | sort -u)"
  printf '%s\n' "None of ${names//$'\n'/, } in the diff files you read matches what is staged or in the working tree of '$repo', so this accept would cover nothing; they match the worktree '$worktree'. $WORKTREE_MISMATCH_REASON"
}

head_commit() {
  git -C "$1" rev-parse --verify --quiet HEAD || printf -- '-\n'
}

record_accept() {
  local repo="$1" state="$2" entries="$3" head
  head="$(head_commit "$repo")"
  mkdir -p "$(dirname "$state")"
  {
    [ ! -f "$state" ] || cat "$state"
    accept_entries "$head" <<<"$entries"
  } | sort -u >"$state.tmp"
  mv "$state.tmp" "$state"
}

minor_only() {
  jq -e '(.findings | length) > 0 and all(.findings[]; .severity == "minor") and (.conflicts | length) == 0' >/dev/null
}

repo_relative() {
  local repo="$1" path dir rest
  while IFS= read -r path; do
    dir="$path" rest=""
    while [ ! -d "$dir" ]; do
      rest="/$(basename "$dir")$rest"
      dir="$(dirname "$dir")"
    done
    dir="$(cd "$dir" && pwd -P)" || continue
    path="$dir$rest"
    case "$path" in "$repo"/?*) printf '%s\n' "${path#"$repo"/}" ;; esac
  done
}

minor_return_paths() {
  local repo="$1" judgment="$2" returned="$3"
  {
    [ -z "$returned" ] || printf '%s\n' "$returned"
    jq -r '.findings[].where[].path' <<<"$judgment" | repo_relative "$repo"
  } | sort -u
}

record_minor_return() {
  local paths="$3"
  [ -n "$paths" ] || return 0
  record_accept "$1" "$2" "$(MINOR_RETURN_COVER="$MINOR_RETURN_COVER" awk 'NF { print ENVIRON["MINOR_RETURN_COVER"] "\t" $0 }' <<<"$paths")"
}

accept_fingerprint() {
  { [ ! -f "$1" ] || cat "$1"; } | set_fingerprint
}

returns_file() {
  printf '%s.returns\n' "$(review_state_file "$1")"
}

findings_file() {
  printf '%s.findings\n' "$(review_state_file "$1")"
}

finding_keys() {
  jq -r '.findings[]? | objects | [(.rule | strings), (.where[0]?.path | strings)] | tojson' 2>/dev/null
}

append_lines() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  {
    [ ! -f "$file" ] || cat "$file"
    RETURN_HEAD="$2" AGENT="$3" awk '{ print ENVIRON["RETURN_HEAD"] "\t" ENVIRON["AGENT"] "\t" $0 }'
  } | sort -u >"$file.tmp"
  mv "$file.tmp" "$file"
}

record_return() {
  local repo="$1" agent="$2" paths="$3" keys="$4" head
  head="$(head_commit "$repo")"
  append_lines "$(returns_file "$repo")" "$head" "$agent" <<<"$paths"
  [ -z "$keys" ] || append_lines "$(findings_file "$repo")" "$head" "$agent" <<<"$keys"
}

returned_before() {
  local repo="$1" agent="$2" returns
  returns="$(returns_file "$repo")"
  [ -f "$returns" ] && AGENT="$agent" awk -F '\t' '$2 == ENVIRON["AGENT"] { found = 1 } END { exit !found }' "$returns"
}

finding_returns_on_commit() {
  local repo="$1" paths="$2" keys="$3" returns findings
  returns="$(returns_file "$repo")"
  findings="$(findings_file "$repo")"
  if [ ! -f "$returns" ] || [ ! -f "$findings" ] || [ -z "$paths" ] || [ -z "$keys" ]; then
    printf '0\n'
    return
  fi
  RETURN_HEAD="$(head_commit "$repo")" awk -F '\t' '
    FILENAME == ARGV[1] { if ($1 == ENVIRON["RETURN_HEAD"]) on_work[$2]; next }
    FILENAME == ARGV[2] { wanted[$0]; next }
    $1 == ENVIRON["RETURN_HEAD"] && ($2 in on_work) && ($3 in wanted) && !seen[$3, $2]++ && ++count[$3] > most { most = count[$3] }
    END { print most + 0 }' <(path_entries "$returns" <<<"$paths") <(printf '%s\n' "$keys") "$findings"
}

named_before() {
  local repo="$1" seen
  shift
  for seen in "$@"; do
    [ "$seen" != "$repo" ] || return 0
  done
  return 1
}

judgment_refused() {
  jq -cn --arg code "$1" --arg why "$2" '{code: $code, why: $why}'
}

returned_paths() {
  local path
  diff_files_paths <<<"$1" | while IFS=$'\t' read -r path _; do
    [ -z "$path" ] || unquote_path "$path"
  done
}

void_returns() {
  local input="$1" reviewer="$2" returned="$3" judgment repo
  jq -c '.tool_input.judgments[]? | objects | select(.verdict == "return" and (.repo | strings | startswith("/")))' <<<"$input" 2>/dev/null |
    while IFS= read -r judgment; do
      repo="$(repo_root "$(jq -r .repo <<<"$judgment")")" && [ -n "$repo" ] || continue
      void_paths "$(review_state_file "$repo")" "$returned"
      record_return "$repo" "$reviewer" "$returned" "$(finding_keys <<<"$judgment")"
    done
}

record_verdict() {
  local input="$1" reads="$2" reviewer="$3" returned="$4" listed reviewed file
  listed="$(jq -r '.tool_input.diffs[]' <<<"$input")"
  reviewed="$(diff_files_paths <<<"$listed")"

  local judgments=() repos=() judgment named repo verdict
  while IFS= read -r judgment; do
    repo="$(repo_root "$(jq -r .repo <<<"$judgment")")" || repo=""
    judgments+=("$judgment")
    repos+=("$repo")
  done < <(jq -c '.tool_input.judgments[]' <<<"$input")

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if ! grep -qxF -- "$file" <<<"$reads"; then
      judgment_refused diff_not_read "You list '$file' in diffs but did not read it with Read. List only the diff files you read."
      return
    fi
  done <<<"$listed"

  local i seen=() cited
  for i in "${!judgments[@]}"; do
    named="$(jq -r .repo <<<"${judgments[$i]}")"
    repo="${repos[$i]}"
    if [ -z "$repo" ]; then
      judgment_refused repo_not_found "'$named' is not a repository. Name the repository the change is in as the judgment's repo."
      return
    fi
    if named_before "$repo" ${seen[@]+"${seen[@]}"}; then
      judgment_refused repo_repeated "'$named' has more than one judgment. $REPO_REPEATED_REASON"
      return
    fi
    seen+=("$repo")
    cited="$(location_paths <<<"${judgments[$i]}" | cited_worktrees "$repo")"
    if [ -n "$cited" ] && ! grep -qxF "$repo" <<<"$cited"; then
      judgment_refused worktree_mismatch "The judgment cites files in '$(head -n 1 <<<"$cited")', another worktree of '$named', and none in '$named'. $WORKTREE_MISMATCH_REASON"
      return
    fi
    if jq -e '.verdict == "accept" and (.findings | length) > 0' <<<"${judgments[$i]}" >/dev/null; then
      judgment_refused accept_with_findings "'$named' is accepted with findings. $ACCEPT_WITH_FINDINGS_REASON"
      return
    fi
  done

  local notes=() entries=() code fix count worktree
  for i in "${!judgments[@]}"; do
    repo="${repos[$i]}"
    verdict="$(jq -r .verdict <<<"${judgments[$i]}")"
    code="" fix="" count=0 entries[i]=""
    if [ "$verdict" = return ]; then
      count="$(finding_returns_on_commit "$repo" "$returned" "$(finding_keys <<<"${judgments[$i]}")")"
    elif returned_before "$repo" "$reviewer"; then
      code=same_reviewer fix="$SAME_REVIEWER_FIX"
    else
      entries[i]="$(current_entries "$repo" <<<"$reviewed")"
      if [ -n "$reviewed" ] && [ -z "${entries[i]}" ]; then
        worktree="$(staged_worktree "$repo" "$reviewed")"
        if [ -n "$worktree" ]; then
          judgment_refused worktree_mismatch "$(covers_nothing_reason "$repo" "$reviewed" "$worktree")"
          return
        fi
        code=accept_covers_nothing fix="$STALE_DIFF_FIX"
      fi
    fi
    notes[i]="$(jq -cn --arg repo "$repo" --arg verdict "$verdict" --arg code "$code" --arg fix "$fix" --argjson count "$count" \
      '{repo: $repo, verdict: $verdict, recorded: ($code == ""), code: (if $code == "" then null else $code end), fix: (if $fix == "" then null else $fix end), finding_returns_on_commit: $count}')"
  done

  local state counts
  for i in "${!judgments[@]}"; do
    repo="${repos[$i]}"
    ! jq -e .code <<<"${notes[$i]}" >/dev/null || continue
    verdict="$(jq -r .verdict <<<"${judgments[$i]}")"
    state="$(review_state_file "$repo")"
    if [ "$verdict" = accept ]; then
      record_accept "$repo" "$state" "${entries[i]}"
    elif minor_only <<<"${judgments[$i]}"; then
      record_minor_return "$repo" "$state" "$(minor_return_paths "$repo" "${judgments[$i]}" "$returned")"
    fi
    counts="$(verdict_counts <<<"${judgments[$i]}")"
    event_log "$input" verdict --arg verdict "$verdict" --arg repo "$repo" --arg fingerprint "$(accept_fingerprint "$state")" \
      --arg reason "$(jq -r '.reason // empty' <<<"${judgments[$i]}")" \
      --argjson findings "$(jq -c .findings <<<"$counts")" --argjson conflicts "$(jq -c .conflicts <<<"$counts")" \
      --argjson follow_ups "$(jq -c .follow_ups <<<"$counts")" --argjson rules "$(jq -c .rules <<<"$counts")"
  done
  printf '%s\n' "${notes[@]}" | jq -sc '{gate: {recorded: true, judgments: .}}'
}
