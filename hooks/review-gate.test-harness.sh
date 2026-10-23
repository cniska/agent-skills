HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/commit-gate.sh"
RECORD="$HERE/review-record.sh"

pass=0
fail=0
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

scratch="$(mktemp -d)" || exit 1
trap 'rm -rf "$scratch"' EXIT
source "$HERE/jq-past-shims.test-harness.sh"
link_jq_past_shims "$scratch"
export HOME="$scratch/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$scratch"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export CLAUDE_PLUGIN_DATA="$scratch/data"
require_jq
mkdir -p "$HOME"

repo="$scratch/repo"
mkdir -p "$repo"
(cd "$repo" && git init -q -b main && printf 'print(1)\n' >app.py && printf '# readme\n' >README.md && git add -A && git commit -q -m base)

denied() {
  local items pronoun=it
  [ "$#" -eq 1 ] || pronoun=them
  items="$(printf '%s, ' "$@")"
  refused "Commit blocked: no diff cniska-skills:reviewer accepted covers ${items%, }, which this commit can carry. A diff file covers a path's staged or working-tree content only when the review brief names that file by its absolute path, the reviewer reads it, and the diff's new side is that content, and only until a later commit changes the path. An edit this commit is not meant to carry can be set aside with git stash, or git stash -u for an untracked file, and restored after the commit without voiding any accept. Otherwise write the current diff of $pronoun to a new file and brief a fresh reviewer naming that file by its absolute path, then commit once it ends with 'Verdict: accept'."
}
refused() { jq -cn --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'; }
blocked() { jq -cn --arg reason "$1" '{decision: "block", reason: $reason}'; }
repo_refusal() { refused "${1:+$1 }Put 'Repo: <absolute path of the repository under review>' on the line above the verdict."; }

readonly LOOK_ALIKE='echo "notes: cd /nowhere && git -C /nowhere commit -m y; git commit -m z"'
readonly QUOTE="'"
twins="$scratch/twins.jsonl"

decide() {
  jq -cn --arg command "$1" --arg cwd "$2" '{tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

gate_from() {
  local decision twin
  decision="$(decide "$1" "$2")"
  if [ -z "$decision" ]; then
    twin="$1"$'\n'"$LOOK_ALIKE"
  else
    twin="echo $QUOTE${1//$QUOTE/$QUOTE\\$QUOTE$QUOTE}$QUOTE"
  fi
  jq -cn --arg command "$twin" --arg got "$(decide "$twin" "$2")" '{command: $command, got: $got}' >>"$twins"
  printf '%s\n' "$decision"
}

gate() { gate_from "$1" "$repo"; }

assistant_line() { jq -cn --argjson block "$1" '{type: "assistant", message: {content: [$block]}}'; }
handback_line() { assistant_line "$(jq -cn --arg message "$1" '{type: "tool_use", name: "SubagentHandback", input: {message: $message}}')"; }
read_line() { assistant_line '{"type": "tool_use", "name": "Read", "input": {"file_path": "/x"}}'; }
text_line() { assistant_line "$(jq -cn --arg text "$1" '{type: "text", text: $text}')"; }

diffs="$scratch/diffs"
mkdir -p "$diffs"
changed_in() { git -C "$1" diff --name-only --no-renames HEAD -- 2>/dev/null; git -C "$1" ls-files --others --exclude-standard; }
diff_in() {
  local root="$1" path post
  shift
  for path in "$@"; do
    post="$(git -C "$root" hash-object -- "$path" 2>/dev/null)" || post=0000000
    printf 'diff --git a/%s b/%s\nindex 0000000..%s 100644\n' "$path" "$path" "${post:0:7}"
  done
}
diff_of() {
  local named root path
  sed -n 's/^Repo: //p' <<<"$1" | while IFS= read -r named; do
    root="$(cd "$named" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || continue
    local paths=()
    while IFS= read -r path; do paths+=("$path"); done < <(changed_in "$root" | sort -u)
    diff_in "$root" ${paths[@]+"${paths[@]}"}
  done
}
brief_line() { jq -cn --arg brief "Review the diff in $1." '{type: "user", message: {content: $brief}}'; }
read_of() { assistant_line "$(jq -cn --arg path "$1" '{type: "tool_use", name: "Read", input: {file_path: $path}}')"; }
briefed() {
  local file
  file="$(mktemp "$diffs/XXXXXX")"
  printf '%s\n' "$1" >"$file"
  brief_line "$file"
  read_of "$file"
}
transcript_of() {
  local file
  file="$(mktemp "$diffs/XXXXXX")"
  printf '%s\n' "$1" >"$file"
  printf '%s\n' "$file"
}

fresh_agent() {
  local count
  count="$(cat "$scratch/agents" 2>/dev/null || printf '0')"
  count=$((count + 1))
  printf '%s\n' "$count" >"$scratch/agents"
  printf 'reviewer-%s\n' "$count"
}

record_reading() {
  jq -cn --arg cwd "$repo" --arg agent "$1" --arg message "$2" --arg type "${4:-cniska-skills:reviewer}" --arg transcript "$(transcript_of "$3")" \
    '{hook_event_name: "PreToolUse", tool_name: "SubagentHandback", tool_input: {message: $message}, agent_type: $type, agent_id: $agent, cwd: $cwd, agent_transcript_path: $transcript}' | "$RECORD" 2>/dev/null
}

record_as() {
  record_reading "$1" "$2" "$(briefed "$(diff_of "$2")")" "${3:-}"
}

record_handback() {
  local agent
  agent="$(fresh_agent)"
  if [ "${2:-}" = again ]; then
    record_as "$agent" "$1" >/dev/null
  fi
  record_as "$agent" "$1"
}

record_last_message() {
  local transcript
  transcript="$(transcript_of "$(briefed "$(diff_of "$1")" && text_line "$1")")"
  jq -cn --arg cwd "$repo" --arg message "$1" --arg agent "$(fresh_agent)" --arg transcript "$transcript" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", agent_id: $agent, cwd: $cwd, last_assistant_message: $message, agent_transcript_path: $transcript}' | "$RECORD" 2>/dev/null
}

sections() { printf '## Findings\n\n%s\n\n## Conflicts\n\n%s\n\n## Clean\n\n- **Use what exists:** app.py\n' "${1:-none}" "${2:-none}"; }
report() { printf '%s\nRepo: %s\nVerdict: %s' "$(sections)" "$1" "$2"; }
finding() { printf -- '- **Where:** app.py:1\n- **Rule:** No dead structure\n- **Severity:** minor\n- **Why:** unused.\n- **Instead:** delete it.'; }
edit() { (cd "$repo" && printf '%s\n' "$2" >>"$1"); }
land() { (cd "$repo" && git add -A && git commit -q -m land); }

log="$CLAUDE_PLUGIN_DATA/events.jsonl"
: >"$twins"

finish() {
  local command got
  while IFS=$'\t' read -r command got; do
    assert "the quoted twin [$command] passes" "$got" ""
  done < <(jq -r '[.command, .got] | @tsv' "$twins")
  assert "every logged line is one JSON object" "$(jq -s 'all(type == "object")' "$log")" true
  assert "every line of a kind has the same fields" "$(jq -s 'group_by(.event) | all(map(keys) | unique | length == 1)' "$log")" true
  printf '%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
