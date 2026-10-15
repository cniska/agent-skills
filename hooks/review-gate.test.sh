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
refused() { jq -cn --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'; }
CREATE="$(refused "Commit blocked: this command creates the repository it commits to, so no reviewer verdict can cover the commit. Run git init or git clone on its own first, then commit once cniska-skills:reviewer has accepted the diff. A scratch repo passes when the command starts with cd <temp path> && or cd \"\$(mktemp -d)\" && and joins every step with &&.")"
readonly CREATE
blocked() { jq -cn --arg reason "$1" '{decision: "block", reason: $reason}'; }
readonly MISSING_REASON="End your report with a last line that is exactly 'Verdict: accept' or 'Verdict: return'."
MISSING="$(refused "$MISSING_REASON")"
MISSING_AT_STOP="$(blocked "$MISSING_REASON")"
readonly MISSING MISSING_AT_STOP
readonly SHAPE="The report is three sections, '## Findings', '## Conflicts' and '## Clean', each saying 'none' when it is empty; each finding is five bullets, '- **Where:**', '- **Rule:** <the rule's heading>', '- **Severity:** critical, major or minor', '- **Why:**' and '- **Instead:**'; then, at the end, 'Repo: <absolute path>' with 'Verdict: accept' or 'Verdict: return' on the line below it, one such pair per repository."
REFERENCE="$HERE/../skills/expertise/principles/references/review-report.md"
labels="$(awk '/^```/ { inside = !inside; next } inside && /^(## |- \*\*[A-Z][a-z]*:\*\*)/' "$REFERENCE" | sed -E 's/^(- \*\*[A-Za-z]+:\*\*).*/\1/')"
assert "the review report reference holds three sections and five finding bullets" "$(printf '%s\n' "$labels" | wc -l | tr -d ' ')" 8
while IFS= read -r label; do
  case "$SHAPE" in *"'$label"*) named=yes ;; *) named=no ;; esac
  assert "the refusal names the review report's $label" "$named" yes
done <<<"$labels"
NO_SECTIONS="$(refused "The report lacks a section. $SHAPE")"
WITH_FINDINGS="$(refused "An accept needs 'none' under '## Findings'; while any finding stands, end with 'Verdict: return'. $SHAPE")"
readonly REPO_REASON="Put 'Repo: <absolute path of the repository under review>' on the line above the verdict."
NO_REPO="$(refused "$REPO_REASON")"
readonly NO_SECTIONS WITH_FINDINGS NO_REPO

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

fresh_agent() {
  local count
  count="$(cat "$scratch/agents" 2>/dev/null || printf '0')"
  count=$((count + 1))
  printf '%s\n' "$count" >"$scratch/agents"
  printf 'reviewer-%s\n' "$count"
}

record_as() {
  jq -cn --arg cwd "$repo" --arg agent "$1" --arg message "$2" --arg type "${3:-cniska-skills:reviewer}" \
    '{hook_event_name: "PreToolUse", tool_name: "SubagentHandback", tool_input: {message: $message}, agent_type: $type, agent_id: $agent, cwd: $cwd}' | "$RECORD" 2>/dev/null
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
  jq -cn --arg cwd "$repo" --arg message "$1" --arg agent "$(fresh_agent)" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", agent_id: $agent, cwd: $cwd, last_assistant_message: $message}' | "$RECORD" 2>/dev/null
}

sections() { printf '## Findings\n\n%s\n\n## Conflicts\n\n%s\n\n## Clean\n\n- **Use what exists:** app.py\n' "${1:-none}" "${2:-none}"; }
report() { printf '%s\nRepo: %s\nVerdict: %s' "$(sections)" "$1" "$2"; }
finding() { printf -- '- **Where:** app.py:1\n- **Rule:** No dead structure\n- **Severity:** minor\n- **Why:** unused.\n- **Instead:** delete it.'; }
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
assert "a Repo line that is not a repository keeps the reviewer running" "$(record_handback "$(report "$scratch/nowhere" accept)")" "$(refused "'$scratch/nowhere' is not a repository. $REPO_REASON")"
assert "a relative Repo path keeps the reviewer running" "$(record_handback "$(report repo accept)")" "$(refused "'repo' is not an absolute path. $REPO_REASON")"
assert "a missing Repo line on the second hand-back lets the reviewer hand back" "$(record_handback $'All good.\nVerdict: accept' again)" ""
assert "a reviewer stopped without a Repo line approved nothing" "$(gate 'git commit -am x')" "$DENIED"

assert "an accepting verdict records nothing to say" "$(record_handback "$(report "$repo" accept)")" ""
assert "an accepted diff commits" "$(gate 'git commit -am x')" ""
edit app.py 'print(3)'
assert "an edit after the accept blocks the commit" "$(gate 'git commit -am x')" "$DENIED"

record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && printf 'x = 1\n' >new.py)
assert "a new untracked file after the accept blocks the commit" "$(gate 'git commit -am x')" "$DENIED"

record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && git add new.py)
assert "staging a new file the reviewer accepted untracked still commits" "$(gate 'git commit -am x')" ""
(cd "$repo" && git reset -q new.py)
assert "unstaging an accepted new file still commits" "$(gate 'git commit -am x')" ""

land
(cd "$repo" && mv app.py moved.py)
record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && git add -A)
assert "staging an accepted move still commits" "$(gate 'git commit -m x')" ""
(cd "$repo" && git mv moved.py app.py)
edit app.py 'print(4)'

record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(report "$repo" return)" >/dev/null
assert "a returning verdict clears the accept" "$(gate 'git commit -am x')" "$DENIED"

SAME_REVIEWER="$(refused "This accept is discarded: you returned this repository's change earlier, and the commit gate takes an accept only from a reviewer that has not. End your report with the line 'Start a fresh cniska-skills:reviewer on the fix's diff; this one returned it.' above your verdict.")"
record_as returner "$(report "$repo" return)" >/dev/null
assert "an accept from the reviewer that returned keeps it running" "$(record_as returner "$(report "$repo" accept)")" "$SAME_REVIEWER"
assert "an accept from the reviewer that returned on its second hand-back lets it hand back" "$(record_as returner "$(report "$repo" accept)")" ""
assert "an accept from the reviewer that returned approves nothing" "$(gate 'git commit -am x')" "$DENIED"
assert "an accept from a fresh reviewer after the return records" "$(record_as fresh "$(report "$repo" accept)")" ""
assert "that fresh accept lets the diff commit" "$(gate 'git commit -am x')" ""
spare="$scratch/spare"
(cd "$scratch" && git init -q -b main spare)
assert "the reviewer that returned may accept another repository" "$(record_as returner "$(report "$spare" accept)")" ""
record_as returner "$(report "$repo" return)" >/dev/null

assert "a report with no verdict keeps the reviewer running" "$(record_handback 'Looks fine to me.')" "$MISSING"
assert "a verdict not on its own line does not count" "$(record_handback 'My Verdict: accept')" "$MISSING"
assert "a missing verdict on the second hand-back lets the reviewer hand back" "$(record_handback 'Still no verdict.' again)" ""

assert "a report without the three sections keeps the reviewer running" "$(record_handback $'Fine.\nRepo: '"$repo"$'\nVerdict: accept')" "$NO_SECTIONS"
assert "a report missing one section keeps the reviewer running" "$(record_handback "$(sections | grep -v '^## Clean$')"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$NO_SECTIONS"
assert "an accept without the sections approves nothing" "$(gate 'git commit -am x')" "$DENIED"
assert "an accept with a finding keeps the reviewer running" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$WITH_FINDINGS"
assert "an accept with 'none' and a finding keeps the reviewer running" "$(record_handback "$(sections "none"$'\n'"$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$WITH_FINDINGS"
assert "an accept with a finding on the second hand-back lets the reviewer hand back" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept' again)" ""
assert "an accept with a finding approves nothing" "$(gate 'git commit -am x')" "$DENIED"
assert "an accept whose Findings says 'None.' counts" "$(record_handback "$(sections 'None.')"$'\nRepo: '"$repo"$'\nVerdict: accept')" ""
assert "that accept lets the diff commit" "$(gate 'git commit -am x')" ""
assert "a return with a finding records nothing to say" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: return')" ""
assert "that return clears the accept" "$(gate 'git commit -am x')" "$DENIED"
record_handback "$(report "$repo" accept)" >/dev/null
assert "a return without the sections on the second hand-back still clears the accept" \
  "$(record_handback $'Bad.\nRepo: '"$repo"$'\nVerdict: return' again; gate 'git commit -am x')" "$DENIED"

assert "a verdict in the last message counts when there is no handback" "$(record_last_message "$(report "$repo" accept)")" ""
assert "that verdict lets the diff commit" "$(gate 'git commit -am x')" ""

assert "a hand-back from an agent other than the reviewer is not judged" "$(record_as worker 'No verdict.' general-purpose)" ""
edit app.py 'print(5)'
assert "an accept handed back by another agent approves nothing" "$(record_as worker "$(report "$repo" accept)" general-purpose; gate 'git commit -am x')" "$DENIED"

transcript="$scratch/late.jsonl"
stop_as() {
  jq -cn --arg cwd "$repo" --arg transcript "$transcript" --arg agent "$1" --arg message "${2:-}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", agent_id: $agent, cwd: $cwd, agent_transcript_path: $transcript, last_assistant_message: $message}' | "$RECORD" 2>/dev/null
}
stop_on() { stop_as "$(fresh_agent)" "${1:-}"; }
stop_late() {
  local message="$1"
  shift
  (sleep 0.5 && "$@" >>"$transcript") &
  stop_on "$message"
  wait
}

record_handback "$(report "$repo" accept)" >/dev/null
read_line >"$transcript"
assert "a stop whose hand-back reaches the transcript late leaves it to the hand-back hook" "$(stop_late '' handback_line "$(report "$repo" return)")" ""
assert "that stop records nothing from the hand-back" "$(gate 'git commit -am x')" ""

{ handback_line "$(report "$repo" accept)" && jq -cn '{type: "attachment", attachment: {type: "hook_blocking_error"}}'; } >"$transcript"
assert "a text end after a block is judged by the text, not the earlier hand-back" "$(stop_late 'Looking again.' text_line 'Looking again.')" "$MISSING_AT_STOP"

{ handback_line "$(report "$repo" accept)" && jq -cn '{type: "user", message: {content: "Look again."}}'; } >"$transcript"
assert "a text end after a resume is judged by the text, not the earlier hand-back" "$(stop_late 'Looking again.' text_line 'Looking again.')" "$MISSING_AT_STOP"

record_handback "$(report "$repo" return)" >/dev/null
text_line "$(report "$repo" accept)" >"$transcript"
assert "a text end with no last message is judged by its final text" "$(stop_on)" ""
assert "that text accept lets the diff commit" "$(gate 'git commit -am x')" ""

edit app.py 'print(6)'
assert "a denied hand-back keeps the reviewer running" "$(record_as texter 'No verdict.')" "$MISSING"
text_line 'No verdict.' >"$transcript"
assert "a run that then ends in text with the same fault stops through the same bound" "$(stop_as texter 'No verdict.')" ""
text_line $'Fine.\nRepo: '"$repo"$'\nVerdict: accept' >"$transcript"
assert "a text end with a fault not yet denied keeps the reviewer running" "$(stop_as texter $'Fine.\nRepo: '"$repo"$'\nVerdict: accept')" "$(blocked "The report lacks a section. $SHAPE")"
assert "neither end approves anything" "$(gate 'git commit -am x')" "$DENIED"

assert "a text stop after an accepting handback is judged by the text alone" "$(stop_on 'Looking again.')" "$MISSING_AT_STOP"

land
edit README.md 'more docs'
assert "a Markdown-only change commits without a verdict" "$(gate 'git commit -am docs')" ""
(cd "$repo" && printf 'x = 1\n' >scratch.py && git add README.md)
assert "a staged Markdown-only change commits beside an untracked code file" "$(gate 'git commit -m docs')" ""
assert "a same-command add of an untracked code file needs a verdict" "$(gate 'git add -A && git commit -m docs')" "$DENIED"
(cd "$repo" && rm scratch.py)
land
(cd "$repo" && git mv app.py app.md)
assert "a staged move of code to Markdown needs a verdict" "$(gate 'git commit -m x')" "$DENIED"
(cd "$repo" && git mv app.md app.py)

worktree="$scratch/topic"
(cd "$repo" && git worktree add -q -b topic "$worktree")
other="$scratch/other"
mkdir -p "$other/sub"
(cd "$other" && git init -q -b main && printf 'z = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'z = 2\n' >>lib.py)

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
mismatch="$(refused "The report cites files in '$(cd "$worktree" && pwd -P)', another worktree of '$repo', and none in '$repo'. Put the path of the worktree the change is in on the 'Repo:' line, not another checkout of its repository.")"
assert "an accept naming the main checkout while citing only a worktree's files keeps the reviewer running" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/app.py:2.\nRepo: '"$repo"$'\nVerdict: accept')" "$mismatch"
assert "an accept citing a worktree's files approves nothing in the main checkout" "$(gate 'git commit -am x')" "$DENIED"
assert "a cited file that does not exist yet still places the worktree" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/new/file.py.\nRepo: '"$repo"$'\nVerdict: accept')" "$mismatch"
assert "an accept citing files in both the main checkout and a worktree records" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/app.py and '"$repo"$'/app.py.\nRepo: '"$repo"$'\nVerdict: accept')" ""
assert "an accept naming the worktree it cites records" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/app.py.\nRepo: '"$worktree"$'\nVerdict: accept')" ""

two_repos() { printf '%s\nRepo: %s\nVerdict: %s\nRepo: %s\n\nVerdict: %s' "$(sections)" "$1" "$2" "$3" "$4"; }
record_handback "$(two_repos "$worktree" accept "$other" accept)" >/dev/null
assert "a report naming two repos lets the first commit" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" ""
assert "a report naming two repos lets the second commit" "$(gate_from 'git commit -am x' "$other")" ""
record_handback "$(two_repos "$worktree" return "$other" accept)" >/dev/null
assert "a return for the first of two repos clears its accept" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$DENIED"
assert "an accept for the second of two repos still stands" "$(gate_from 'git commit -am x' "$other")" ""
assert "a Repo line with text between it and the verdict pairs with nothing" "$(record_handback "$(sections)"$'\nRepo: '"$repo"$'\nAll good.\nVerdict: accept')" "$NO_REPO"
assert "a verdict with no Repo line above it beside a paired one keeps the reviewer running" \
  "$(record_handback "$(sections)"$'\nRepo: '"$repo"$'\nVerdict: accept\nAll good.\nVerdict: return')" "$NO_REPO"
assert "two pairs naming one repository keep the reviewer running" \
  "$(record_handback "$(two_repos "$repo" return "$repo" accept)")" \
  "$(refused "'$repo' has more than one verdict. Give each repository one verdict: name it in one 'Repo:' line only.")"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(sections)"$'\nRepo: '"$repo"$'\nVerdict: return\nAll good.\nVerdict: return' >/dev/null
assert "a return beside an unpaired verdict still clears its accept" "$(gate 'git commit -am x')" "$DENIED"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(two_repos "$repo" return "$repo" accept)" >/dev/null
assert "a return beside a second pair for its repository still clears its accept" "$(gate 'git commit -am x')" "$DENIED"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(two_repos "$scratch/nowhere" accept "$repo" return)" >/dev/null
assert "a return after a pair naming no repository still clears its accept" "$(gate 'git commit -am x')" "$DENIED"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(sections)"$'\nAll good.\nVerdict: accept\nRepo: '"$repo"$'\nVerdict: return' >/dev/null
assert "a return after an unpaired verdict still clears its accept" "$(gate 'git commit -am x')" "$DENIED"
assert "a report with two bad pairs is denied for the first" \
  "$(record_handback "$(two_repos relative accept "$scratch/nowhere" accept)")" \
  "$(refused "'relative' is not an absolute path. $REPO_REASON")"
assert "a second pair naming no repository keeps the reviewer running" \
  "$(record_handback "$(two_repos "$worktree" accept "$scratch/nowhere" accept)")" \
  "$(refused "'$scratch/nowhere' is not a repository. $REPO_REASON")"

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
  'cd ~/project && git commit -m x && git add -A && git commit -m y' \
  'git commit -m a && git commit -m b'; do
  assert "a command with two commits [$command] is refused" "$(gate_from "$command" "$scratch")" "$MULTIPLE"
done
assert "a commit quoted inside bash -c is not a command the gate reads" "$(gate_from "bash -c 'git commit -am x'" "$home_repo")" ""
for command in \
  $'cat >msg.txt <<EOF\ngit commit -m a && git commit -m b\nEOF\ngit -C ~/project commit -F msg.txt' \
  $'cat <<-\'EOF\' >msg.txt\n\tgit commit -m a\n\tEOF\ngit -C ~/project commit -F msg.txt' \
  "grep -n 'git commit' notes.txt && git -C ~/project commit -am x" \
  "grep -n 'git init' notes.txt && git -C ~/project commit -am x" \
  "jq -r 'select(.command | test(\"git commit\"))' log.jsonl; git -C ~/project commit -am x"; do
  assert "one commit beside commit text in [$command] is gated as one" "$(gate_from "$command" "$scratch")" "$DENIED"
done
for command in \
  $'cat <<EOF\ngit commit -m a\nEOF' \
  "grep -rn 'git commit' hooks" \
  "jq -r 'select(.command | contains(\"git commit\"))' log.jsonl"; do
  assert "commit text with no commit in [$command] passes" "$(gate_from "$command" "$home_repo")" ""
done
for command in \
  "echo \"\$(git -C ~/project commit -am x)\"" \
  "echo \"\`git -C ~/project commit -am x\`\"" \
  "echo \`git -C ~/project commit -am x\`" \
  "echo \"unbalanced && git -C ~/project commit -am x" \
  "echo \"a && git -C ~/project commit -am x\" 'unbalanced" \
  "bash -lc 'git status && git -C ~/project commit -am x'" \
  "cd '$home_repo' && git commit -am x"; do
  assert "a commit in quotes that still run, or after an unbalanced quote, [$command] is gated" "$(gate_from "$command" "$scratch")" "$DENIED"
done
assert "two commits on separate lines are refused" "$(gate_from $'git -C ~/project commit -am x\ngit -C ~/project commit -am y' "$scratch")" "$MULTIPLE"
assert "a commit after a closed heredoc is still counted" "$(gate_from $'cat <<EOF\nx\nEOF\ngit -C ~/project commit -am x && git -C ~/project commit -am y' "$scratch")" "$MULTIPLE"
assert "a commit that creates its repo outside a temp directory is refused" "$(gate_from 'git init -q && git commit -m x' /)" "$CREATE"
assert "a scratch repo created and committed to under a temp directory passes" \
  "$(gate_from 'git init -q -b main r && cd r && git commit -q --allow-empty -m i && git init -q --bare ../o.git' "$scratch")" ""
assert "a scratch repo created, added and committed in a temp directory passes" "$(gate_from 'git init -q && git add -A && git commit -qm start' "$scratch")" ""
assert "a scratch repo named by an absolute temp path passes" "$(gate_from "git init -q $scratch/s && cd $scratch/s && git commit -m x" "$scratch")" ""
assert "a scratch repo named by an absolute temp path from a cwd outside the temp directories is refused" "$(gate_from "git init -q $scratch/s && cd $scratch/s && git commit -m x" /)" "$CREATE"
for command in \
  "git init -q && git -C $scratch status && git commit -m x" \
  "(cd $scratch) && git init -q && git commit -m x"; do
  assert "a temp target that may not move the commit [$command] from outside the temp directories is refused" "$(gate_from "$command" /)" "$CREATE"
done
for command in \
  'git init -q /usr/r && cd /usr/r && git commit -m x' \
  'git init -q ../r && cd .. && git commit -m x' \
  'git init -q && cd && git commit -m x' \
  'git init -q && cd - && git commit -m x' \
  "git init -q && cd \"\$X\" && git commit -m x" \
  'git init -q && GIT_DIR=/usr/r/.git git commit -m x'; do
  assert "a repo created in a temp directory whose commit may land elsewhere [$command] is refused" "$(gate_from "$command" "$scratch")" "$CREATE"
done
assert "a scratch repo under a home outside the temp directories is refused" "$(HOME=/usr gate_from 'git init -q ~/r && cd ~/r && git commit -m x' "$scratch")" "$CREATE"
assert "a repo created from a cwd outside the temp directories with a relative cd is refused" "$(gate_from 'git init -q r && cd r && git commit -m x' /)" "$CREATE"
assert "a commit after cloning into a temp directory passes" "$(gate_from 'git clone -q ~/project copy && git -C copy commit -m x' "$scratch")" ""
checkout="$(cd "$HERE/.." && pwd)"
for command in \
  "cd $scratch/x && git init -q && git commit -m x" \
  "cd $scratch/y && git init -q && git commit -m a && git commit -m b" \
  "git -C $scratch/w init -q && git -C $scratch/w commit -m a && git -C $scratch/w commit -m b" \
  "cd \"\$(mktemp -d)\" && git init -q && git commit -m x" \
  'cd /tmp && git clone -q ~/project copy && git -C copy commit -m x'; do
  assert "a scratch repo reached from a checkout as [$command] passes" "$(gate_from "$command" "$checkout")" ""
done
for command in \
  'cd /usr/x && git init -q && git commit -m x' \
  'cd /usr/x && git init -q && git commit -m a && git commit -m b' \
  "cd $scratch/z && git init -q && git commit -m a && cd $checkout && git commit -m b" \
  "cd $scratch/z && git init -q && git commit -m a && git -C $checkout commit -m b" \
  "cd $scratch/z && git init -q; git commit -m x" \
  "cd $scratch/z; git init -q && git commit -m x" \
  "cd $scratch/z && git init -q || git commit -m x" \
  "git -C $scratch/w init -q && git -C $scratch/w commit -m a && git commit -m b" \
  "git init -q $scratch/w && git -C w commit -m x" \
  "git init -q $scratch/w && echo \"git -C $scratch/w commit\" && git commit -m x" \
  "(cd $scratch/z) && git init -q && git commit -m x" \
  "cd \"\$(mktemp)\" && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d /usr/gate.XXXXXX)\" && git init -q && git commit -m x" \
  "cd \$(mktemp -d /tmp/gate.XXXXXX)/w && git init -q && git commit -m x" \
  "cd \"\$(mktemp -dp /tmp)\" && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d /tmp/gate)\" && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d /tmp/gate-missing/w.XXXXXX)\" && git init -q && git commit -m x" \
  "D=\$(mktemp -d) && cd \$D && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d)\"; git init -q && git commit -m x" \
  'git clone -q ~/project copy && git -C copy commit -m x'; do
  assert "a repo created from a checkout whose commit may land outside the temp directories [$command] is refused" "$(gate_from "$command" "$checkout")" "$CREATE"
done
recorded() { local command; command="$(<"$HERE/fixtures/commit-gate/denied-$1.txt")" || return; printf '%s' "${command//@S@/$scratch}"; }
mktemp_sh_c_newlines="$(recorded mktemp-sh-c-newlines)" || exit 1
clone_literal_temp="$(recorded clone-literal-temp)" || exit 1
s_variable_semicolons="$(recorded s-variable-semicolons)" || exit 1
d_variable="$(recorded d-variable)" || exit 1
set_e_semicolons="$(recorded set-e-semicolons)" || exit 1
assert "a denied scratch command that commits inside sh -c across newlines is still refused" "$(gate_from "$mktemp_sh_c_newlines" "$checkout")" "$CREATE"
assert "a denied scratch command that clones under a literal temp path joined by && passes" "$(gate_from "$clone_literal_temp" "$checkout")" ""
assert "a denied scratch command that reaches its directory through S= and ; is still refused" "$(gate_from "$s_variable_semicolons" "$checkout")" "$CREATE"
assert "a denied scratch command that reaches its directory through D= is still refused" "$(gate_from "$d_variable" "$checkout")" "$CREATE"
assert "a denied scratch command that runs set -e; S= and ; is still refused" "$(gate_from "$set_e_semicolons" "$checkout")" "$CREATE"
mkdir -p "$scratch/locked"
chmod 555 "$scratch/locked"
assert "a mktemp -d under a TMPDIR it cannot write to is refused" "$(TMPDIR="$scratch/locked" gate_from "cd \"\$(mktemp -d)\" && git init -q && git commit -m x" "$checkout")" "$CREATE"
chmod 755 "$scratch/locked"
gate_stderr() { jq -cn --arg command "$1" --arg cwd "$2" '{tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | { "$GATE" >/dev/null; } 2>&1; }
for command in \
  'cd /usr/x && git init -q && git commit -m x' \
  'git init -q && git commit -m x' \
  'cd /usr && git commit -am x' \
  'git commit -am x'; do
  assert "a commit outside the temp directories [$command] says nothing on stderr" "$(gate_stderr "$command" /)" ""
done
record_handback "$(report "$repo" accept)" >/dev/null
assert "a git -C commit quoted in echo does not name the commit's repo" "$(gate_from "echo \"git -C $repo commit\" && git commit -am x" "$home_repo")" "$DENIED"
assert "a look-alike in a heredoc leaves a commit gated" "$(gate_from $'cat >notes.txt <<EOF\n'"$LOOK_ALIKE"$'\nEOF\ngit -C ~/project commit -am x' "$scratch")" "$DENIED"
assert "a look-alike in a heredoc adds no commit" "$(gate_from $'cat >notes.txt <<\'EOF\'\n'"$LOOK_ALIKE"$'\nEOF\ngit status' "$scratch")" ""

printf 'not json' | "$GATE" >/dev/null 2>&1
assert "a gate that fails refuses the commit rather than allowing it" "$?" 2

assert "recording a verdict without plugin data fails" \
  "$(printf '{"agent_type":"cniska-skills:reviewer","last_assistant_message":""}' | env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null 2>&1; echo "$?")" 1
assert "recording a verdict without plugin data names the script and the variable" \
  "$(printf '{"agent_type":"cniska-skills:reviewer","last_assistant_message":""}' | { env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null; } 2>&1)" "review-record.sh: CLAUDE_PLUGIN_DATA is required"

edit app.py 'print(12)'
assert "recording a verdict without an agent id fails" \
  "$(jq -cn --arg cwd "$repo" --arg message "$(report "$repo" accept)" '{agent_type: "cniska-skills:reviewer", cwd: $cwd, last_assistant_message: $message}' | "$RECORD" 2>&1 >/dev/null; echo "$?")" \
  "review-record.sh: agent_id is required to tell reviewers apart
1"
assert "a verdict without an agent id approves nothing" "$(gate 'git commit -am x')" "$DENIED"

assert "a stop of an agent other than the reviewer is not judged" \
  "$(jq -cn --arg cwd "$repo" '{hook_event_name: "SubagentStop", agent_type: "general-purpose", agent_id: "w1", cwd: $cwd, last_assistant_message: "No verdict."}' | "$RECORD" 2>/dev/null)" ""
assert "the verdict recorder judges every subagent's stop" \
  "$(jq -r '.hooks.SubagentStop[] | select(has("matcher") | not) | .hooks[].command' "$HERE/hooks.json" | grep -c 'review-record.sh$')" 1
assert "the verdict recorder judges every hand-back" \
  "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "SubagentHandback") | .hooks[].command' "$HERE/hooks.json" | grep -c 'review-record.sh$')" 1

log="$CLAUDE_PLUGIN_DATA/events.jsonl"
logged="$scratch/logged"
mkdir -p "$logged"
(cd "$logged" && git init -q -b main && printf 'n = 1\n' >n.py && printf '# n\n' >NOTES.md && git add -A && git commit -q -m base)
logged_head="$(git -C "$logged" rev-parse HEAD)"
logged_repo="$(git -C "$logged" rev-parse --show-toplevel)"

gate_logged() {
  jq -cn --arg command "$1" --arg cwd "${2:-$logged}" \
    '{session_id: "s1", agent_id: "a1", hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

record_logged() {
  jq -cn --arg cwd "$logged" --arg message "$1" --arg agent "$reviewer" \
    '{session_id: "s1", agent_id: $agent, hook_event_name: "PreToolUse", tool_name: "SubagentHandback", tool_input: {message: $message}, agent_type: "cniska-skills:reviewer", cwd: $cwd}' | "$RECORD" 2>/dev/null
}
reviewer=r1

lines() { if [ -f "$log" ]; then wc -l <"$log" | tr -d ' '; else echo 0; fi; }
new_lines() { tail -n +"$(($1 + 1))" "$log" 2>/dev/null; }

decided() {
  local before
  before="$(lines)"
  "$@" >/dev/null
  new_lines "$before" | jq -c 'del(.ts, .v, .session, .agent, .cwd, .event)'
}

fingerprint_of() { (source "$HERE/review-state.sh" && diff_fingerprint "$1"); }
carried_of() { (source "$HERE/review-state.sh" && carried_paths "$1" "$2"); }
assert "listing carried paths in an unknown untracked mode fails" "$(carried_of "$logged" bogus >/dev/null 2>&1; echo "$?")" 1

before="$(lines)"
gate_logged 'git status' >/dev/null
assert "a command that is not a commit logs nothing" "$(new_lines "$before")" ""

(cd "$logged" && printf 'n = 2\n' >n.py)
fp="$(fingerprint_of "$logged")"
before="$(lines)"
gate_logged 'git commit -am x' >/dev/null
assert "a gate decision logs one line with the common fields" \
  "$(new_lines "$before" | jq -c --arg cwd "$logged" '[.v, .event, .session, .agent, .cwd == $cwd, (.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))]')" \
  '[1,"gate","s1","a1",true,true]'
assert "an unreviewed commit logs a deny with the diff it judged" \
  "$(new_lines "$before" | jq -c 'del(.ts, .v, .session, .agent, .cwd, .event)')" \
  "$(jq -cn --arg repo "$logged_repo" --arg head "$logged_head" --arg fp "$fp" '{gate: "commit", decision: "deny", reason: "not_accepted", repo: $repo, head: $head, fingerprint: $fp}')"

assert "an accepting verdict logs the verdict and the diff it accepted" \
  "$(decided record_logged "$(report "$logged" accept)")" \
  "$(jq -cn --arg repo "$logged_repo" --arg fp "$fp" '{verdict: "accept", repo: $repo, fingerprint: $fp, reason: null, findings: {critical: 0, major: 0, minor: 0, fix: 0, consider: 0, unrated: 0}, conflicts: 0, rules: []}')"
assert "the verdict line names the reviewer's agent id" "$(tail -n 1 "$log" | jq -r .agent)" r1
assert "the accepted commit logs an allow with the same fingerprint" \
  "$(decided gate_logged 'git commit -am x')" \
  "$(jq -cn --arg repo "$logged_repo" --arg head "$logged_head" --arg fp "$fp" '{gate: "commit", decision: "allow", reason: "accepted", repo: $repo, head: $head, fingerprint: $fp}')"
(cd "$logged" && printf 'n = 3\n' >n.py)
reviewer=r2
assert "an edit after the accept logs changed_since_accept" "$(decided gate_logged 'git commit -am x' | jq -r .reason)" changed_since_accept
assert "a returning verdict logs the return" "$(decided record_logged "$(report "$logged" return)" | jq -r --arg repo "$logged_repo" '[.verdict, .repo == $repo] | @tsv')" "return	true"
counts() { decided record_logged "$(sections "$1" "$2")"$'\nRepo: '"$logged"$'\nVerdict: return' | jq -c '[.findings, .conflicts, .rules]'; }
readonly EVERY_SEVERITY='- **Where:** n.py:1
- **Rule:** No dead structure
- **Severity:** critical
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:2
- **Rule:** Named constants
- **Severity:** Major.
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:3
- **Rule:** No dead structure
- **Severity:** minor
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:4
- **Severity:** severe
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:5
- **Rule:** Names
- **Why:** a.
- **Instead:** b.'
readonly TWO_CONFLICTS='- **Where:** n.py:6
- **Rule:** A settled decision
- **Severity:** major
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:7
- **Rule:** Another
- **Severity:** minor
- **Why:** a.
- **Instead:** b.'
assert "a return counts its findings by severity, its conflicts and each finding's rule" \
  "$(counts "$EVERY_SEVERITY" "$TWO_CONFLICTS")" \
  '[{"critical":1,"major":1,"minor":1,"fix":0,"consider":0,"unrated":2},2,["No dead structure","Named constants","No dead structure","Names"]]'
assert "findings in prose rather than bullets leave the verdict uncounted" \
  "$(counts 'The constant on line 2 is unused.' none)" '[null,null,null]'
assert "a conflict in prose rather than bullets leaves the verdict uncounted" \
  "$(counts "$(finding)" 'The brief settles this the other way.')" '[null,null,null]'
assert "an uncounted return is still logged" "$(tail -n 1 "$log" | jq -r .verdict)" return
many="$(for _ in $(seq 1001); do printf -- '- **Where:** n.py:1\n- **Severity:** minor\n'; done)"
assert "more than 1000 findings of a kind leave the verdict uncounted" "$(counts "$many" none)" '[null,null,null]'
assert "a report naming two repositories leaves each verdict uncounted" \
  "$(decided record_logged "$(sections)"$'\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$other"$'\nVerdict: return' | jq -sc 'map([.findings, .conflicts, .rules])')" \
  '[[null,null,null],[null,null,null]]'
assert "a commit after a return logs not_accepted" "$(decided gate_logged 'git commit -am x' | jq -r .reason)" not_accepted

(cd "$logged" && git checkout -q n.py && printf 'more\n' >>NOTES.md)
assert "a Markdown-only commit logs an allow" "$(decided gate_logged 'git commit -am x' | jq -c '[.decision, .reason, .fingerprint]')" '["allow","no_code_change",null]'
assert "a commit outside any repository logs an allow" "$(decided gate_logged 'git commit -am x' "$scratch" | jq -c '[.decision, .reason, .repo]')" '["allow","outside_repo",null]'
assert "two commits in one command log multiple_commits" "$(decided gate_logged 'git commit -m x && git commit -m y' | jq -r .reason)" multiple_commits
assert "a commit that creates its repo logs repo_created" "$(decided gate_logged 'git init -q && git commit -m x' / | jq -r .reason)" repo_created
assert "a commit to a scratch repo logs an allow" "$(decided gate_logged 'git init -q && git commit -m x' | jq -c '[.decision, .reason, .repo]')" '["allow","scratch_repo",null]'
assert "a commit reaching its repo unclearly logs repo_unclear" "$(decided gate_logged '(cd ~/project && git commit -am x)' | jq -r .reason)" repo_unclear
assert "a commit naming no repository logs repo_not_found" "$(decided gate_logged 'cd ~/nowhere && git commit -am x' | jq -r .reason)" repo_not_found
assert "a gate that fails logs gate_error" "$(decided sh -c "printf 'not json' | '$GATE' 2>/dev/null" | jq -r '[.decision, .reason] | @tsv')" "deny	gate_error"

assert "a report with no verdict logs a deny" "$(decided record_logged 'No verdict.' | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	missing_verdict"
assert "the second hand-back without a verdict logs an allow" "$(decided record_logged 'No verdict.' | jq -r '[.decision, .reason] | @tsv')" "allow	missing_verdict"
assert "a report with no Repo line logs missing_repo" "$(decided record_logged $'Fine.\nVerdict: accept' | jq -r .reason)" missing_repo
assert "a relative Repo path logs repo_relative" "$(decided record_logged "$(report logged accept)" | jq -r .reason)" repo_relative
assert "a report without the sections logs missing_findings" "$(decided record_logged $'Fine.\nRepo: '"$logged"$'\nVerdict: return' | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	missing_findings"
reviewer=r3
assert "an accept with a finding logs accept_with_findings" "$(decided record_logged "$(sections "$(finding)")"$'\nRepo: '"$logged"$'\nVerdict: accept' | jq -r .reason)" accept_with_findings
assert "a return for a brief with no diff logs reason no_diff" "$(decided record_logged "$(sections)"$'\nReason: no_diff\nRepo: '"$logged"$'\nVerdict: return' | jq -r '[.verdict, .reason] | @tsv')" "return	no_diff"
assert "a no_diff return beside an accept for another repo logs the reason on its own pair only" \
  "$(decided record_logged "$(sections)"$'\nReason: no_diff\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$other"$'\nVerdict: accept' | jq -sc 'map(.reason)')" '["no_diff",null]'
assert "a verdict with no Reason line logs a null reason" "$(decided record_logged "$(report "$logged" return)" | jq -c .reason)" null
assert "two pairs naming one repository log repo_repeated" "$(decided record_logged "$(sections)"$'\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$logged"$'\nVerdict: accept' | jq -r .reason)" repo_repeated
record_logged "$(report "$logged" return)" >/dev/null
assert "an accept from the reviewer that returned logs same_reviewer" "$(decided record_logged "$(report "$logged" accept)" | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	same_reviewer"
before="$(lines)"
record_logged "$(report "$logged" accept)" >/dev/null
assert "its second hand-back logs an allow and no verdict" "$(new_lines "$before" | jq -sc 'map([.event, .decision, .reason])')" '[["gate","allow","same_reviewer"]]'
assert "a Repo path that is not a repository logs repo_not_found" "$(decided record_logged "$(report "$scratch/nowhere" accept)" | jq -r .reason)" repo_not_found

(cd "$logged" && git checkout -q NOTES.md && printf 'n = 4\n' >n.py)
mv "$log" "$log.kept"
mkdir "$log"
assert "an unwritable log leaves a deny unchanged" "$(gate_logged 'git commit -am x')" "$DENIED"
assert "an unwritable log leaves the deny's exit code at 0" "$(gate_logged 'git commit -am x' >/dev/null; echo "$?")" 0
assert "an unwritable log warns on stderr" \
  "$(jq -cn --arg cwd "$logged" '{tool_input: {command: "git commit -am x"}, cwd: $cwd}' | { "$GATE" >/dev/null; } 2>&1 | grep -c '^commit-gate.sh: the event log was not written')" 1
reviewer=r4
assert "an unwritable log still records an accept" "$(record_logged "$(report "$logged" accept)")" ""
assert "an unwritable log leaves an allow unchanged" "$(gate_logged 'git commit -am x')" ""
rmdir "$log"
mv "$log.kept" "$log"
assert "every logged line is one JSON object" "$(jq -s 'all(type == "object")' "$log")" true
assert "every line of a kind has the same fields" "$(jq -s 'group_by(.event) | all(map(keys) | unique | length == 1)' "$log")" true

while IFS=$'\t' read -r command got; do
  assert "the quoted twin [$command] passes" "$got" ""
done < <(jq -r '[.command, .got] | @tsv' "$twins")

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
