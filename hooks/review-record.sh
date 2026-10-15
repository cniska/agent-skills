#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"
source "$HERE/subagent-gate.sh"
source "$HERE/event-log.sh"

readonly MISSING_VERDICT_REASON="End your report with a last line that is exactly 'Verdict: accept' or 'Verdict: return'."
readonly MISSING_REPO_REASON="Put 'Repo: <absolute path of the repository under review>' on the line above the verdict."
readonly WORKTREE_MISMATCH_REASON="Put the path of the worktree the change is in on the 'Repo:' line, not another checkout of its repository."
readonly REPO_REPEATED_REASON="Give each repository one verdict: name it in one 'Repo:' line only."
readonly REPORT_SHAPE="The report is three sections, '## Findings', '## Conflicts' and '## Clean', each saying 'none' when it is empty; each finding is five bullets, '- **Where:**', '- **Rule:** <the rule's heading>', '- **Severity:** critical, major or minor', '- **Why:**' and '- **Instead:**'; then, at the end, 'Repo: <absolute path>' with 'Verdict: accept' or 'Verdict: return' on the line below it, one such pair per repository."
readonly MISSING_FINDINGS_REASON="The report lacks a section. $REPORT_SHAPE"
readonly SAME_REVIEWER_REASON="This accept is discarded: you returned this repository's change earlier, and the commit gate takes an accept only from a reviewer that has not. End your report with the line 'Start a fresh cniska-skills:reviewer on the fix's diff, with the change's earlier diff files to read as context; this one returned it.' above your verdict."
readonly ACCEPT_WITH_FINDINGS_REASON="An accept needs 'none' under '## Findings'; while any finding stands, end with 'Verdict: return'. $REPORT_SHAPE"
readonly MAX_COUNT=1000
readonly UNCOUNTED='{"findings":null,"conflicts":null,"rules":null}'

die() {
  printf 'review-record.sh: %s\n' "$1" >&2
  exit 1
}

malformed_report() {
  local input="$1" code="$2" reason="$3" decision=allow
  if deny_once "$input" "$code" "$reason"; then
    decision=deny
  fi
  event_log "$input" gate --arg gate verdict --arg decision "$decision" --arg reason "$code" \
    --arg repo "" --arg head "" --arg fingerprint ""
}

parse_report() {
  jq -cRs '
    def bullet($name): "^- \\*\\*" + $name + ":\\*\\*";
    def value($name): sub(bullet($name); "") | sub("^\\s+|\\s+$"; ""; "g");
    def severity: value("Severity") | ascii_downcase | (capture("^(?<kind>critical|major|minor)\\b").kind // "unrated");
    def blank: test("^\\s*$");
    def none: test("^none\\.?$"; "i");
    def last_finding(f): .findings[(.findings | length) - 1] |= f;
    reduce (split("\n")[]) as $line ({headings: [], section: null, findings_lines: 0, findings_none: 0, findings: [], conflicts: 0, prose: false};
      if ($line | test("^## ")) then .section = $line[3:] | .headings += [.section]
      elif ($line | blank) then .
      elif .section == "Findings" then
        .findings_lines += 1
        | if ($line | none) then .findings_none += 1
          elif ($line | test(bullet("Where"))) then .findings += [{severity: "unrated", rule: null}]
          elif (.findings | length) == 0 then .prose = true
          elif ($line | test(bullet("Severity"))) then last_finding(.severity = ($line | severity))
          elif ($line | test(bullet("Rule"))) then last_finding(.rule = ($line | value("Rule") | if . == "" then null else . end))
          else . end
      elif .section == "Conflicts" then
        if ($line | none) then .
        elif ($line | test(bullet("Where"))) then .conflicts += 1
        elif .conflicts == 0 then .prose = true
        else . end
      else . end)
    | {headings, findings_empty: (.findings_lines == 1 and .findings_none == 1), findings, conflicts, prose}'
}

has_sections() {
  jq -e '["Findings", "Conflicts", "Clean"] - .headings == []' >/dev/null
}

findings_empty() {
  jq -e .findings_empty >/dev/null
}

verdict_counts() {
  local repos="$1" parsed="$2"
  if [ "$repos" -ne 1 ]; then
    printf '%s\n' "$UNCOUNTED"
    return
  fi
  jq -c --argjson max "$MAX_COUNT" --argjson uncounted "$UNCOUNTED" '
    ({critical: 0, major: 0, minor: 0, fix: 0, consider: 0, unrated: 0}
      + (.findings | group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries)) as $findings
    | if .prose or ([$findings[], .conflicts] | max) > $max then $uncounted
      else {findings: $findings, conflicts, rules: [.findings[].rule | select(. != null)]} end' <<<"$parsed"
}

verdict_pairs() {
  awk '/^Reason: no_diff$/{reason = substr($0, 9); repo = ""; next} /^Repo: /{repo = substr($0, 7); next} /^Verdict: (accept|return)$/ {print substr($0, 10) "\037" repo "\037" (repo == "" ? "" : reason)} NF {repo = ""; reason = ""}'
}

cited_worktrees() {
  local repo="$1" worktrees common path dir
  worktrees="$(git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p')"
  common="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)"
  common="$(cd "$common" && pwd -P)"
  { grep -v '^Repo: ' | grep -Eo "/[^[:space:]\`'\"():,]+" || true; } | sort -u | while IFS= read -r path; do
    dir="$path"
    while [ ! -d "$dir" ]; do
      dir="$(dirname "$dir")"
    done
    dir="$(cd "$dir" && pwd -P)" || continue
    case "$dir/" in "$common"/*) continue ;; esac
    awk -v dir="$dir/" 'index(dir, $0 "/") == 1 && length($0) > length(best) {best = $0} END {if (best != "") print best}' <<<"$worktrees"
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

reviewed_paths() {
  local transcript file
  transcript="$(agent_transcript "$1")"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
  jq -nrR '
    [inputs | fromjson? | objects] as $lines
    | ([$lines[] | select(.type == "user")][0].message.content // ""
      | if type == "string" then . else [.[]? | .text? // empty] | join("\n") end) as $brief
    | [$lines[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Read")
      | .input.file_path? | select(type == "string" and . != "") | select(. as $path | $brief | contains($path))]
    | unique[]' "$transcript" | while IFS= read -r file; do
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

current_paths() {
  local repo="$1" path post mode blob head_entry_mode
  while IFS=$'\t' read -r path post mode; do
    [ -n "$path" ] || continue
    path="$(unquote_path "$path")"
    if [[ $post == @* ]]; then
      read -r head_entry_mode _ post _ < <(git --literal-pathspecs -C "$repo" ls-tree HEAD -- "$(unquote_path "${post#@}")") || true
      [ -n "$post" ] || continue
      [ -n "$mode" ] || mode="$head_entry_mode"
    fi
    if [[ $post =~ ^0+$ ]]; then
      [ -e "$repo/$path" ] || [ -L "$repo/$path" ] || printf '%s\n' "$path"
    elif blob="$(working_blob "$repo" "$path")" && [[ $blob == "$post"* ]] && [ "$(working_mode "$repo" "$path")" = "$mode" ]; then
      printf '%s\n' "$path"
    fi
  done
}

record_accept() {
  local state="$1" fingerprint="$2" paths="$3"
  mkdir -p "$(dirname "$state")"
  {
    printf '%s\n' "$fingerprint"
    {
      if [ -f "$state" ] && [ "$(accepted_fingerprint "$state")" = "$fingerprint" ]; then
        accepted_paths "$state"
      fi
      printf '%s\n' "$paths"
    } | sed '/^$/d' | sort -u
  } >"$state.tmp"
  mv "$state.tmp" "$state"
}

returns_file() {
  printf '%s.returns\n' "$(review_state_file "$1")"
}

record_return() {
  local repo="$1" agent="$2" returns
  returns="$(returns_file "$repo")"
  mkdir -p "$(dirname "$returns")"
  printf '%s\n' "$agent" >>"$returns"
}

returned_before() {
  local repo="$1" agent="$2" returns
  returns="$(returns_file "$repo")"
  [ -f "$returns" ] && grep -qxF "$agent" "$returns"
}

named_before() {
  local repo="$1" seen
  shift
  for seen in "$@"; do
    [ "$seen" != "$repo" ] || return 0
  done
  return 1
}

main() {
  jq --version >/dev/null 2>&1 || die "jq is required to read the reviewer's verdict"
  local input agent
  input="$(cat)"
  judges "$input" cniska-skills:reviewer || return 0
  ! left_to_handback "$input" || return 0
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    die "CLAUDE_PLUGIN_DATA is required"
  fi
  agent="$(jq -r '.agent_id // empty' <<<"$input")"
  [ -n "$agent" ] || die "agent_id is required to tell reviewers apart"

  local report pairs
  report="$(subagent_report "$input")"
  pairs="$(verdict_pairs <<<"$report")"
  if [ -z "$pairs" ]; then
    malformed_report "$input" missing_verdict "$MISSING_VERDICT_REASON"
    return
  fi

  local verdicts=() repos=() reasons=() verdict named reason repo accepts=0 code="" why="" pair_code pair_why cited
  while IFS=$'\037' read -r verdict named reason; do
    pair_code=""
    if [ -z "$named" ]; then
      pair_code=missing_repo pair_why="$MISSING_REPO_REASON"
    elif [[ $named != /* ]]; then
      pair_code=repo_relative pair_why="'$named' is not an absolute path. $MISSING_REPO_REASON"
    elif ! repo="$(repo_root "$named")" || [ -z "$repo" ]; then
      pair_code=repo_not_found pair_why="'$named' is not a repository. $MISSING_REPO_REASON"
    else
      if [ "$verdict" = return ]; then
        rm -f "$(review_state_file "$repo")"
        record_return "$repo" "$agent"
      fi
      cited="$(cited_worktrees "$repo" <<<"$report")"
      if named_before "$repo" ${repos[@]+"${repos[@]}"}; then
        pair_code=repo_repeated pair_why="'$named' has more than one verdict. $REPO_REPEATED_REASON"
      elif [ -n "$cited" ] && ! grep -qxF "$repo" <<<"$cited"; then
        pair_code=worktree_mismatch pair_why="The report cites files in '$(head -n 1 <<<"$cited")', another worktree of '$named', and none in '$named'. $WORKTREE_MISMATCH_REASON"
      elif [ "$verdict" = accept ] && returned_before "$repo" "$agent"; then
        pair_code=same_reviewer pair_why="$SAME_REVIEWER_REASON"
      fi
    fi
    if [ -n "$pair_code" ]; then
      [ -n "$code" ] || code="$pair_code" why="$pair_why"
      continue
    fi
    verdicts+=("$verdict")
    repos+=("$repo")
    reasons+=("$reason")
    [ "$verdict" = return ] || accepts=$((accepts + 1))
  done <<<"$pairs"
  if [ -n "$code" ]; then
    malformed_report "$input" "$code" "$why"
    return
  fi

  local parsed
  parsed="$(parse_report <<<"$report")" || die "jq could not read the reviewer's report"
  if ! has_sections <<<"$parsed"; then
    malformed_report "$input" missing_findings "$MISSING_FINDINGS_REASON"
    return
  elif [ "$accepts" -gt 0 ] && ! findings_empty <<<"$parsed"; then
    malformed_report "$input" accept_with_findings "$ACCEPT_WITH_FINDINGS_REASON"
    return
  fi

  local i state fingerprint counts findings conflicts rules reviewed
  reviewed="$(reviewed_paths "$input")"
  counts="$(verdict_counts "${#repos[@]}" "$parsed")" || die "jq could not count the reviewer's findings"
  findings="$(jq -c .findings <<<"$counts")"
  conflicts="$(jq -c .conflicts <<<"$counts")"
  rules="$(jq -c .rules <<<"$counts")"
  for i in "${!repos[@]}"; do
    state="$(review_state_file "${repos[$i]}")"
    fingerprint="$(diff_fingerprint "${repos[$i]}")"
    if [ "${verdicts[$i]}" = accept ]; then
      record_accept "$state" "$fingerprint" "$(current_paths "${repos[$i]}" <<<"$reviewed")"
    fi
    event_log "$input" verdict --arg verdict "${verdicts[$i]}" --arg repo "${repos[$i]}" --arg fingerprint "$fingerprint" \
      --arg reason "${reasons[$i]}" --argjson findings "$findings" \
      --argjson conflicts "$conflicts" --argjson rules "$rules"
  done
}

main "$@"
