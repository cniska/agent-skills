#!/usr/bin/env bash
set -u

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

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
export HOME="$scratch/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$scratch"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export CLAUDE_PLUGIN_DATA="$scratch/data"
mkdir -p "$HOME"

repo="$scratch/repo"
mkdir -p "$repo"
(cd "$repo" && git init -q -b main && printf 'print(1)\n' >app.py && printf '# readme\n' >README.md && git add -A && git commit -q -m base)

readonly DENIED='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: cniska-skills:reviewer has not accepted this diff. Hand the change to cniska-skills:reviewer and commit once it ends with '"'"'Verdict: accept'"'"', with no edits since."}}'
readonly MISSING='{"decision":"block","reason":"End your report with a last line that is exactly '"'"'Verdict: accept'"'"' or '"'"'Verdict: return'"'"'."}'

gate() {
  jq -cn --arg command "$1" --arg cwd "$repo" '{tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

record_handback() {
  local transcript="$scratch/transcript.jsonl"
  jq -cn --arg message "$1" '{type: "assistant", message: {content: [{type: "tool_use", name: "SubagentHandback", input: {message: $message}}]}}' >"$transcript"
  jq -cn --arg cwd "$repo" --arg transcript "$transcript" --arg active "${2:-false}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", cwd: $cwd, agent_transcript_path: $transcript, last_assistant_message: "", stop_hook_active: ($active == "true")}' | "$RECORD" 2>/dev/null
}

record_last_message() {
  jq -cn --arg cwd "$repo" --arg message "$1" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", cwd: $cwd, last_assistant_message: $message, stop_hook_active: false}' | "$RECORD" 2>/dev/null
}

edit() { (cd "$repo" && printf '%s\n' "$2" >>"$1"); }
land() { (cd "$repo" && git add -A && git commit -q -m land); }

assert "a commit with nothing changed passes" "$(gate 'git commit -m x')" ""
edit app.py 'print(2)'
assert "an unreviewed code change blocks the commit" "$(gate 'git commit -am x')" "$DENIED"
assert "a command that is not a commit passes" "$(gate 'git status')" ""
assert "a commit word in another git command passes" "$(gate 'git log --grep commit')" ""
assert "a commit through an absolute git path is gated" "$(gate '/usr/bin/git -C . commit -m x')" "$DENIED"
assert "a commit after cd and && is gated" "$(gate "cd $repo && git commit -m x")" "$DENIED"

assert "an accepting verdict records nothing to say" "$(record_handback $'All good.\nVerdict: accept')" ""
assert "an accepted diff commits" "$(gate 'git commit -am x')" ""
edit app.py 'print(3)'
assert "an edit after the accept blocks the commit" "$(gate 'git commit -am x')" "$DENIED"

record_handback $'Fine.\nVerdict: accept' >/dev/null
(cd "$repo" && printf 'x = 1\n' >new.py)
assert "a new untracked file after the accept blocks the commit" "$(gate 'git commit -am x')" "$DENIED"

record_handback $'Fine.\nVerdict: accept' >/dev/null
record_handback $'Problems below.\nVerdict: return' >/dev/null
assert "a returning verdict clears the accept" "$(gate 'git commit -am x')" "$DENIED"

assert "a report with no verdict keeps the reviewer running" "$(record_handback 'Looks fine to me.')" "$MISSING"
assert "a verdict not on its own line does not count" "$(record_handback 'My Verdict: accept')" "$MISSING"
assert "a missing verdict on the second stop lets the reviewer stop" "$(record_handback 'Still no verdict.' true)" ""

assert "a verdict in the last message counts when there is no handback" "$(record_last_message $'Ok.\nVerdict: accept')" ""
assert "that verdict lets the diff commit" "$(gate 'git commit -am x')" ""

land
edit README.md 'more docs'
assert "a Markdown-only change commits without a verdict" "$(gate 'git commit -am docs')" ""
land

worktree="$scratch/topic"
(cd "$repo" && git worktree add -q -b topic "$worktree")
other="$scratch/other"
mkdir -p "$other"
(cd "$other" && git init -q -b main && printf 'z = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'z = 2\n' >>lib.py)

record_reads() {
  local transcript="$scratch/reads.jsonl" message="$1"
  shift
  : >"$transcript"
  local path
  for path in "$@"; do
    jq -cn --arg p "$path" '{type: "assistant", message: {content: [{type: "tool_use", name: "Read", input: {file_path: $p}}]}}' >>"$transcript"
  done
  jq -cn --arg message "$message" '{type: "assistant", message: {content: [{type: "tool_use", name: "SubagentHandback", input: {message: $message}}]}}' >>"$transcript"
  jq -cn --arg cwd "$repo" --arg transcript "$transcript" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", cwd: $cwd, agent_transcript_path: $transcript, last_assistant_message: "", stop_hook_active: false}' | "$RECORD" 2>/dev/null
}
gate_from() {
  jq -cn --arg command "$1" --arg cwd "$2" '{tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

(cd "$worktree" && printf 'print(9)\n' >>app.py)
assert "a commit after cd into a worktree is gated against that worktree" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$DENIED"
assert "a commit through git -C on a worktree is gated against that worktree" "$(gate_from "git -C $worktree commit -am x" "$repo")" "$DENIED"
record_reads $'Fine.\nVerdict: accept' "$worktree/app.py" "$other/lib.py" >/dev/null
assert "an accept for files the reviewer read in a worktree lets that worktree commit" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" ""
assert "a reviewer reading a file in an unrelated repo approves nothing there" "$(gate_from 'git commit -am x' "$other")" "$DENIED"
edit app.py 'print(10)'
assert "an accept for a worktree does not approve the main checkout" "$(gate 'git commit -am x')" "$DENIED"

assert "the verdict recorder listens to the reviewer agent" "$(grep -c '"matcher": "^cniska-skills:reviewer$"' "$HERE/hooks.json")" 1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
