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

readonly DENIED='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: cniska-skills:reviewer has not accepted this diff. Hand the change to cniska-skills:reviewer with the absolute path of its repo and commit once it ends with '"'"'Verdict: accept'"'"', with no edits since."}}'
readonly UNRESOLVED='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: ~/nowhere is not a repository, so the reviewer verdict for this commit cannot be checked. Name the repository by an absolute path in cd."}}'
readonly MULTIPLE='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: this command runs more than one git commit, and the reviewer gate checks one commit per command. Run each commit as its own command."}}'
readonly AMBIGUOUS='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: this command reaches its repository in a way the reviewer gate cannot follow, so the verdict for this commit cannot be checked. Commit with '"'"'cd <absolute path> && git commit ...'"'"'."}}'
readonly CREATE='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: this command creates the repository it commits to, so no reviewer verdict can cover the commit. Run git init or git clone on its own first, then commit once cniska-skills:reviewer has accepted the diff."}}'
readonly MISSING='{"decision":"block","reason":"End your report with a last line that is exactly '"'"'Verdict: accept'"'"' or '"'"'Verdict: return'"'"'."}'
readonly NO_REPO='{"decision":"block","reason":"Put '"'"'Repo: <absolute path of the repository under review>'"'"' on the line above the verdict."}'

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

report() { printf 'Fine.\nRepo: %s\nVerdict: %s' "$1" "$2"; }
edit() { (cd "$repo" && printf '%s\n' "$2" >>"$1"); }
land() { (cd "$repo" && git add -A && git commit -q -m land); }

assert "a commit with nothing changed passes" "$(gate 'git commit -m x')" ""
edit app.py 'print(2)'
assert "an unreviewed code change blocks the commit" "$(gate 'git commit -am x')" "$DENIED"
assert "a command that is not a commit passes" "$(gate 'git status')" ""
assert "a commit word in another git command passes" "$(gate 'git log --grep commit')" ""
assert "a commit through an absolute git path is gated" "$(gate '/usr/bin/git -C . commit -m x')" "$DENIED"
assert "a commit after cd and && is gated" "$(gate "cd $repo && git commit -m x")" "$DENIED"

assert "a verdict with no Repo line keeps the reviewer running" "$(record_handback $'All good.\nVerdict: accept')" "$NO_REPO"
assert "an accept with no Repo line approves nothing" "$(gate 'git commit -am x')" "$DENIED"
assert "a Repo line that is not a repository keeps the reviewer running" "$(record_handback "$(report "$scratch/nowhere" accept)")" "{\"decision\":\"block\",\"reason\":\"'$scratch/nowhere' is not a repository. Put 'Repo: <absolute path of the repository under review>' on the line above the verdict.\"}"
assert "a relative Repo path keeps the reviewer running" "$(record_handback "$(report repo accept)")" "{\"decision\":\"block\",\"reason\":\"'repo' is not an absolute path. Put 'Repo: <absolute path of the repository under review>' on the line above the verdict.\"}"
assert "a missing Repo line on the second stop lets the reviewer stop" "$(record_handback $'All good.\nVerdict: accept' true)" ""
assert "a reviewer stopped without a Repo line approved nothing" "$(gate 'git commit -am x')" "$DENIED"

assert "an accepting verdict records nothing to say" "$(record_handback "$(report "$repo" accept)")" ""
assert "an accepted diff commits" "$(gate 'git commit -am x')" ""
edit app.py 'print(3)'
assert "an edit after the accept blocks the commit" "$(gate 'git commit -am x')" "$DENIED"

record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && printf 'x = 1\n' >new.py)
assert "a new untracked file after the accept blocks the commit" "$(gate 'git commit -am x')" "$DENIED"

record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(report "$repo" return)" >/dev/null
assert "a returning verdict clears the accept" "$(gate 'git commit -am x')" "$DENIED"

assert "a report with no verdict keeps the reviewer running" "$(record_handback 'Looks fine to me.')" "$MISSING"
assert "a verdict not on its own line does not count" "$(record_handback 'My Verdict: accept')" "$MISSING"
assert "a missing verdict on the second stop lets the reviewer stop" "$(record_handback 'Still no verdict.' true)" ""

assert "a verdict in the last message counts when there is no handback" "$(record_last_message "$(report "$repo" accept)")" ""
assert "that verdict lets the diff commit" "$(gate 'git commit -am x')" ""

land
edit README.md 'more docs'
assert "a Markdown-only change commits without a verdict" "$(gate 'git commit -am docs')" ""
land

worktree="$scratch/topic"
(cd "$repo" && git worktree add -q -b topic "$worktree")
other="$scratch/other"
mkdir -p "$other/sub"
(cd "$other" && git init -q -b main && printf 'z = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'z = 2\n' >>lib.py)

gate_from() {
  jq -cn --arg command "$1" --arg cwd "$2" '{tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

(cd "$worktree" && printf 'print(9)\n' >>app.py)
assert "a commit after cd into a worktree is gated against that worktree" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$DENIED"
assert "a commit through git -C on a worktree is gated against that worktree" "$(gate_from "git -C $worktree commit -am x" "$repo")" "$DENIED"
record_handback "$(report "$worktree" accept)" >/dev/null
assert "an accept naming a worktree lets that worktree commit" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" ""
assert "an accept naming a worktree approves nothing in another repo" "$(gate_from 'git commit -am x' "$other")" "$DENIED"
(cd "$worktree" && printf 'print(11)\n' >>app.py)
record_handback "$(report "$other/sub" accept)" >/dev/null
assert "an accept naming a path outside the session's repo lets that repo commit" "$(gate_from 'git commit -am x' "$other")" ""
assert "an accept naming one repo approves nothing in another" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$DENIED"
edit app.py 'print(10)'
assert "an accept for a worktree does not approve the main checkout" "$(gate 'git commit -am x')" "$DENIED"

home_repo="$HOME/project"
mkdir -p "$home_repo"
(cd "$home_repo" && git init -q -b main && printf 'a = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'a = 2\n' >>lib.py)
assert "a commit after cd into a ~ path is gated against that repo" "$(gate_from 'cd ~/project && git commit -am x' "$scratch")" "$DENIED"
assert "a commit through git -C with a ~ path is gated" "$(gate_from 'git -C ~/project commit -am x' "$scratch")" "$DENIED"
assert "a commit after cd into a \$HOME path is gated" "$(gate_from "cd \$HOME/project && git commit -am x" "$scratch")" "$DENIED"
assert "a commit after cd into a quoted path is gated" "$(gate_from "cd \"$home_repo\" && git commit -am x" "$scratch")" "$DENIED"
assert "a commit after cd into a \${HOME} path is gated" "$(gate_from "cd \${HOME}/project && git commit -am x" "$scratch")" "$DENIED"
assert "a commit after cd into a bare ~ is gated against the home repo" "$(HOME="$home_repo" gate_from 'cd ~ && git commit -am x' "$scratch")" "$DENIED"
assert "a commit after cd and ; is gated against that repo" "$(gate_from 'cd ~/project; git commit -am x' "$scratch")" "$DENIED"
assert "a commit message that mentions cd does not hide the repo" "$(gate_from "cd ~/project && git commit -am 'cd into place'" "$scratch")" "$DENIED"
assert "a commit naming a directory that is not a repository is refused" "$(gate_from 'cd ~/nowhere && git commit -am x' "$scratch")" "$UNRESOLVED"
assert "a commit from outside any repository naming none passes to git, which refuses it" "$(gate_from 'git commit -am x' "$scratch")" ""
for command in \
  '(cd ~/project && git commit -am x)' \
  'git add -A && cd ~/project && git commit -am x' \
  'pushd ~/project && git commit -am x' \
  'git -C ~/project -C . commit -am x' \
  'cd ~/project && git -C sub commit -am x' \
  'GIT_DIR=~/project/.git git commit -am x' \
  'GIT_WORK_TREE=~/project git commit -am x' \
  'git --git-dir=~/project/.git commit -am x' \
  "bash -c 'cd ~/project && git commit -am x'" \
  '(cd ~/project && git commit)'; do
  assert "a commit reaching its repo as [$command] is refused" "$(gate_from "$command" "$scratch")" "$AMBIGUOUS"
done
for command in \
  'git -C ~/project commit -am x && git -C ~/other commit -am y' \
  'cd ~/project && git commit -am x && cd ~/other && git commit -am y' \
  'cd ~/project && git commit -m x && git add -A && git commit -m y'; do
  assert "a command with two commits [$command] is refused" "$(gate_from "$command" "$scratch")" "$MULTIPLE"
done
assert "a commit quoted inside bash -c is gated" "$(gate_from "bash -c 'git commit -am x'" "$home_repo")" "$DENIED"
assert "a commit that creates its repo in the same command is refused" "$(gate_from 'git init -q && git add -A && git commit -m x' "$scratch")" "$CREATE"
assert "a commit after cloning in the same command is refused" "$(gate_from 'git clone -q ~/project copy && git -C copy commit -m x' "$scratch")" "$CREATE"

printf 'not json' | "$GATE" >/dev/null 2>&1
assert "a gate that fails refuses the commit rather than allowing it" "$?" 2

assert "the verdict recorder listens to the reviewer agent" "$(grep -c '"matcher": "^cniska-skills:reviewer$"' "$HERE/hooks.json")" 1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
