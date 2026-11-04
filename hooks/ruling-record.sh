readonly WRONG_CALLER_REASON="Only a top-level session that no cniska-skills agent runs may record a ruling. Report the returns to whoever rules."

readonly RULING_ADDS_PATHS='
  def adds_paths: .review == "commit" and (.call | . == "work_right" or . == "owner_decision" or . == "owner_instruction");'

readonly RULING_VIOLATIONS='include "report-schema";'"$RULING_ADDS_PATHS"'
  def owner_judges: .call == "owner_decision" or .call == "owner_instruction";
  .tool_input
  | [tool_violations($schemas[0]; "ruling") | violation_text] as $shape
  | if ($shape | length) > 0 then $shape[]
    else
      (select(.call == "work_right" and (has("findings") | not)) | "/findings is required when /call is \"work_right\""),
      (select(owner_judges and (has("owner_words") | not)) | "/owner_words is required when /call is \(.call | tojson)"),
      (select((owner_judges | not) and has("owner_words")) | "/owner_words is given only when /call is \"owner_decision\" or \"owner_instruction\""),
      (select(.call == "owner_instruction" and .review != "commit") | "/call is \"owner_instruction\" only when /review is \"commit\""),
      (select(adds_paths and ((.diffs // []) | length) == 0) | "/diffs must name each diff you read when the ruling accepts a commit"),
      (select((adds_paths | not) and has("diffs")) | "/diffs is given only when the ruling accepts a commit, since nothing else adds paths to the gate")
    end'

ruling_refused() {
  pre_tool_deny "$2"
  gate_line "$1" deny "$3" "${4:-}"
}

ruling_caller_allowed() {
  [ -z "$(field "$1" agent_id)" ] && [[ "$(field "$1" agent_type)" != cniska-skills:* ]]
}

record_ruled_accept() {
  local input="$1" named repo listed reads file reviewed entries worktree
  listed="$(jq -r '.tool_input.diffs[]' <<<"$input")"
  reads="$(transcript_reads "$(field "$input" transcript_path)")"
  while IFS= read -r file; do
    if ! grep -qxF -- "$file" <<<"$reads"; then
      ruling_refused "$input" "You list '$file' in diffs but did not read it with Read in this session. Read the diff, then record the ruling." diff_not_read
      return 1
    fi
  done <<<"$listed"
  named="$(jq -r .tool_input.repo <<<"$input")"
  repo="$(repo_root "$named")" || repo=""
  if [ -z "$repo" ]; then
    ruling_refused "$input" "'$named' is not a repository. Name the worktree the change is in as repo." repo_not_found
    return 1
  fi
  reviewed="$(diff_files_paths <<<"$listed")"
  entries="$(current_entries "$repo" <<<"$reviewed")"
  if [ -n "$entries" ]; then
    record_accept "$repo" "$(review_state_file "$repo")" "$entries" || die "the ruling cannot be recorded for $repo"
    return
  fi
  worktree=""
  [ -z "$reviewed" ] || worktree="$(staged_worktree "$repo" "$reviewed")"
  if [ -n "$worktree" ]; then
    ruling_refused "$input" "$(covers_nothing_reason "$repo" "$reviewed" "$worktree")" worktree_mismatch "$repo"
    return 1
  fi
  ruling_refused "$input" "The diffs you read match nothing staged or in the working tree of '$repo', so this ruling would cover nothing. Write a new diff of the change, read it, and record the ruling with it." accept_covers_nothing "$repo"
  return 1
}

on_ruling() {
  local input="$1" violations
  if ! ruling_caller_allowed "$input"; then
    ruling_refused "$input" "$WRONG_CALLER_REASON" wrong_agent
    return
  fi
  violations="$(jq -r -L "$HERE" --slurpfile schemas "$SCHEMAS" "$RULING_VIOLATIONS" <<<"$input")" || die "jq could not check the ruling"
  if [ -n "$violations" ]; then
    ruling_refused "$input" "The ruling does not match the ruling tool's schema:"$'\n'"$violations"$'\n'"Call the tool again with each of these fixed." payload_invalid
    return
  fi
  if jq -e "$RULING_ADDS_PATHS"' .tool_input | adds_paths' <<<"$input" >/dev/null; then
    record_ruled_accept "$input" || return 0
  fi
  event_log "$input" tag --arg key ruling --arg value "$(jq -r .tool_input.call <<<"$input")"
  pre_tool_allow
}
