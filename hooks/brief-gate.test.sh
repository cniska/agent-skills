#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/brief-gate.sh"

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

source "$HERE/jq-past-shims.test-harness.sh"
require_jq

readonly NO_SHELL="Reviewer brief refused: cniska-skills:reviewer has no shell, so it reads only files named by absolute path."

start() {
  jq -cn --arg prompt "$1" --arg type "${2:-cniska-skills:reviewer}" \
    '{hook_event_name: "PreToolUse", tool_name: "Agent", tool_input: {description: "review", prompt: $prompt, subagent_type: $type}}' |
    "$HOOK" 2>/dev/null
}
refused() { jq -cn --arg reason "$NO_SHELL $1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'; }
bare() { refused "Name each diff or log file by its absolute path: $1."; }
git_read() { refused "It cannot run $1: write each command's output to a file in your temp folder and name the file by its absolute path."; }

assert "a brief naming a diff by its bare name is refused" \
  "$(start 'History, all in /Users/me/tmp/task/: the fix commit as a whole is fix3-v3.diff')" "$(bare fix3-v3.diff)"
assert "a brief naming a log by a relative path is refused" "$(start 'The log is in tmp/branch.log.')" "$(bare tmp/branch.log)"
assert "a brief naming a diff under ~ is refused" "$(start 'Read `~/tmp/fix.diff`.')" "$(bare \~/tmp/fix.diff)"
assert "a brief naming a diff by a relative path after a branch name is refused" "$(start 'Read (main:docs/fix.diff).')" "$(bare docs/fix.diff)"
assert "an absolute path after a colon passes, as the commit gate reads it" "$(start 'Read main:/Users/me/fix.diff.')" ""
assert "an absolute path in angle brackets passes, as the commit gate reads it" "$(start 'Read </Users/me/fix.diff>;</Users/me/b.log>')" ""
assert "a bare name joined to an absolute path by a comma is refused" "$(start 'Read /Users/me/a.diff,b.diff;c.log')" "$(bare 'b.diff, c.log')"
assert "every bare name is listed once, sorted" "$(start 'b.diff, a.diff and b.diff')" "$(bare 'a.diff, b.diff')"
assert "a brief asking for git show with -C is refused" \
  "$(start 'via `git -C /Users/me/code/app show v1-limit:docs/architecture.md`')" "$(git_read 'git -C')"
assert "a brief asking for git show is refused" "$(start 'Run git show HEAD~1:app.py.')" "$(git_read 'git show')"
assert "a brief asking for git diff is refused" "$(start 'See git diff main...topic')" "$(git_read 'git diff')"
assert "a brief asking for git log -p is refused" "$(start 'Read git log -p main..topic.')" "$(git_read 'git log -p')"
assert "a brief asking for git log with a later --patch is refused" \
  "$(start 'Read git log main..topic --patch.')" "$(git_read 'git log main..topic --patch')"
assert "a brief with a bare name and a git command names both" "$(start $'Read fix.diff\nthen git diff')" \
  "$(refused "Name each diff or log file by its absolute path: fix.diff. It cannot run git diff: write each command's output to a file in your temp folder and name the file by its absolute path.")"

assert "a brief naming every diff and log by absolute path passes" \
  "$(start 'Read /Users/me/tmp/task/fix3-v3.diff, `/Users/me/tmp/task/branch.log` and [the first](/Users/me/tmp/task/fix1.diff).')" ""
assert "a brief that says .diff without a name passes" "$(start 'Each .diff file is named by absolute path.')" ""
assert "a file whose name only starts with a diff name passes" "$(start 'Ignore fix.diff.bak and notes.diffs.')" ""
assert "a brief naming git log without a patch passes" "$(start 'The branch log came from git log --oneline main..topic.')" ""
assert "a -p after git log ends at a semicolon passes" "$(start 'From git log --oneline main..topic; mkdir -p /Users/me/tmp')" ""
assert "a -p after git log ends at a comma passes" \
  "$(start 'Branch log: /Users/me/tmp/log.txt (git log --oneline main..topic, run after mkdir -p /Users/me/tmp)')" ""
assert "a brief that holds no file or git command passes" "$(start 'Judge the design in the plan.')" ""
assert "a bare name in a start of another agent type passes" "$(start 'Read fix.diff and git diff' cniska-skills:researcher)" ""
assert "a start with no agent type passes" \
  "$(jq -cn '{tool_name: "Agent", tool_input: {prompt: "Read fix.diff"}}' | "$HOOK" 2>/dev/null)" ""
assert "a refusal exits 0, so the host reads the decision" "$(start 'fix.diff' >/dev/null; echo "$?")" 0
assert "input that is not JSON passes with exit 0" "$(printf 'not json' | "$HOOK" 2>/dev/null; echo "$?")" 0
assert "input that is not JSON says so on stderr" "$(printf 'not json' | "$HOOK" 2>&1 >/dev/null)" \
  "brief-gate.sh: allowed the agent start unchecked: its input is not JSON"

scratch="$(mktemp -d)" || exit 1
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/bin"
printf '#!/bin/sh\nexit 127\n' >"$scratch/bin/jq"
chmod +x "$scratch/bin/jq"
without_jq() { printf '{}' | PATH="$scratch/bin:$PATH" "$HOOK"; }
assert "a start without a working jq passes with exit 0" "$(without_jq 2>/dev/null; echo "$?")" 0
assert "a start without a working jq names jq on stderr" "$(without_jq 2>&1 >/dev/null)" \
  "brief-gate.sh: allowed the agent start unchecked: jq is required"

assert "the gate runs before each Agent start" \
  "$(jq -r '[.hooks.PreToolUse[] | select(.matcher == "Agent") | .hooks[].command] | join(" ")' "$HERE/hooks.json")" \
  "\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/brief-gate.sh"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
