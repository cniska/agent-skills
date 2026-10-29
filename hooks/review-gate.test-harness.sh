HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/commit-gate.sh"
RECORD="$HERE/report-record.sh"
readonly VERDICT_TOOL=mcp__plugin_cniska-skills_report__verdict

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
  local items pronoun=its
  [ "$#" -eq 1 ] || pronoun=their
  items="$(printf '%s, ' "$@")"
  refused "Commit blocked: no diff cniska-skills:reviewer accepted covers ${items%, }, which this commit can carry. A diff covers a path's staged or working-tree content while the reviewer read its file, listed it in its verdict call's diffs, and its new side is that content, until a later commit changes the path. A path a .gitattributes marks linguist-generated counts as code until HEAD holds that marking, so commit a .gitattributes change alone, reviewed, first. An edit this commit should not carry can wait in git stash (-u if untracked), voiding no accept. Otherwise write $pronoun current diff to a new file, brief a fresh reviewer naming it by absolute path, and commit once that reviewer's verdict call accepts it."
}
refused() { jq -cn --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'; }
allowed() { jq -cn '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow"}}'; }

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
  jq -r .repo <<<"$1" | while IFS= read -r named; do
    root="$(cd "$named" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || continue
    local paths=()
    while IFS= read -r path; do paths+=("$path"); done < <(changed_in "$root" | sort -u)
    diff_in "$root" ${paths[@]+"${paths[@]}"}
  done
}
read_of() { assistant_line "$(jq -cn --arg path "$1" '{type: "tool_use", name: "Read", input: {file_path: $path}}')"; }
scratch_file() {
  local file
  file="$(mktemp "$diffs/XXXXXX")"
  printf '%s\n' "$1" >"$file"
  printf '%s\n' "$file"
}
briefed() { read_of "$(scratch_file "$1")"; }

fresh_agent() {
  local count
  count="$(cat "$scratch/agents" 2>/dev/null || printf '0')"
  count=$((count + 1))
  printf '%s\n' "$count" >"$scratch/agents"
  printf 'reviewer-%s\n' "$count"
}

reads_in() { jq -r 'select(.type == "assistant") | .message.content[] | select(.type == "tool_use" and .name == "Read") | .input.file_path' <<<"$1"; }

record_listing() {
  local agent="$1" judgments="$2" transcript="$3" listed="$4" type="${5:-cniska-skills:reviewer}"
  jq -cn --arg cwd "$repo" --arg agent "$agent" --arg type "$type" --arg tool "$VERDICT_TOOL" --arg transcript "$(scratch_file "$transcript")" \
    --arg listed "$listed" --argjson judgments "$(jq -sc . <<<"$judgments")" '
    {hook_event_name: "PreToolUse", session_id: "s0", tool_name: $tool, tool_input: {diffs: ($listed | split("\n") | map(select(. != ""))), judgments: $judgments},
      agent_type: $type, agent_id: $agent, cwd: $cwd, agent_transcript_path: $transcript}' | "$RECORD" 2>/dev/null
}

record_reading() {
  record_listing "$1" "$2" "$3" "$(reads_in "$3")" "${4:-}"
}

record_as() {
  record_reading "$1" "$2" "$(briefed "$(diff_of "$2")")" "${3:-}"
}

record_handback() {
  record_as "$(fresh_agent)" "$1"
}

stored() { cat "$CLAUDE_PLUGIN_DATA/reports/$1.json" 2>/dev/null; }

report() {
  jq -cn --arg repo "$1" --arg verdict "$2" '{repo: $repo, verdict: $verdict, findings: [], conflicts: [], follow_ups: [], clean: []}' | jq -c "${3:-.}"
}
finding() {
  jq -cn --arg path "$1" --arg rule "${2:-No dead structure}" --arg severity "${3:-minor}" \
    '{where: [{path: $path, line: 1}], rule: $rule, severity: $severity, why: "It is unused.", instead: "Delete it."}'
}
clean_at() { jq -cn --arg path "$1" '{rule: "Use what exists", places: [{path: $path}]}'; }
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
