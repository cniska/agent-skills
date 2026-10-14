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
readonly SHAPE="The report is three sections, '## Findings', '## Conflicts' and '## Clean', each saying 'none' when it is empty; each finding is four bullets, '- **Where:**', '- **Rule:** <the rule's heading>', '- **Why:**' and '- **Instead:**'; then, at the end, 'Repo: <absolute path>' with 'Verdict: accept' or 'Verdict: return' on the line below it, one such pair per repository."
NO_SECTIONS="$(jq -cn --arg reason "The report lacks a section. $SHAPE" '{decision: "block", reason: $reason}')"
WITH_FINDINGS="$(jq -cn --arg reason "An accept needs 'none' under '## Findings'; while any finding stands, end with 'Verdict: return'. $SHAPE" '{decision: "block", reason: $reason}')"
readonly NO_SECTIONS WITH_FINDINGS
readonly NO_REPO='{"decision":"block","reason":"Put '"'"'Repo: <absolute path of the repository under review>'"'"' on the line above the verdict."}'

gate() {
  jq -cn --arg command "$1" --arg cwd "$repo" '{tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

assistant_line() { jq -cn --argjson block "$1" '{type: "assistant", message: {content: [$block]}}'; }
handback_line() { assistant_line "$(jq -cn --arg message "$1" '{type: "tool_use", name: "SubagentHandback", input: {message: $message}}')"; }
read_line() { assistant_line '{"type": "tool_use", "name": "Read", "input": {"file_path": "/x"}}'; }
text_line() { assistant_line "$(jq -cn --arg text "$1" '{type: "text", text: $text}')"; }

record_handback() {
  local transcript="$scratch/transcript.jsonl"
  handback_line "$1" >"$transcript"
  jq -cn --arg cwd "$repo" --arg transcript "$transcript" --arg active "${2:-false}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", cwd: $cwd, agent_transcript_path: $transcript, last_assistant_message: "", stop_hook_active: ($active == "true")}' | "$RECORD" 2>/dev/null
}

record_last_message() {
  jq -cn --arg cwd "$repo" --arg message "$1" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", cwd: $cwd, last_assistant_message: $message, stop_hook_active: false}' | "$RECORD" 2>/dev/null
}

sections() { printf '## Findings\n\n%s\n\n## Conflicts\n\nnone\n\n## Clean\n\n- **Use what exists:** app.py\n' "${1:-none}"; }
report() { printf '%s\nRepo: %s\nVerdict: %s' "$(sections)" "$1" "$2"; }
finding() { printf -- '- **Where:** app.py:1\n- **Rule:** No dead structure\n- **Why:** unused.\n- **Instead:** delete it.'; }
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

assert "a report with no verdict keeps the reviewer running" "$(record_handback 'Looks fine to me.')" "$MISSING"
assert "a verdict not on its own line does not count" "$(record_handback 'My Verdict: accept')" "$MISSING"
assert "a missing verdict on the second stop lets the reviewer stop" "$(record_handback 'Still no verdict.' true)" ""

assert "a report without the three sections keeps the reviewer running" "$(record_handback $'Fine.\nRepo: '"$repo"$'\nVerdict: accept')" "$NO_SECTIONS"
assert "a report missing one section keeps the reviewer running" "$(record_handback "$(sections | grep -v '^## Clean$')"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$NO_SECTIONS"
assert "an accept without the sections approves nothing" "$(gate 'git commit -am x')" "$DENIED"
assert "an accept with a finding keeps the reviewer running" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$WITH_FINDINGS"
assert "an accept with 'none' and a finding keeps the reviewer running" "$(record_handback "$(sections "none"$'\n'"$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$WITH_FINDINGS"
assert "an accept with a finding on the second stop lets the reviewer stop" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept' true)" ""
assert "an accept with a finding approves nothing" "$(gate 'git commit -am x')" "$DENIED"
assert "an accept whose Findings says 'None.' counts" "$(record_handback "$(sections 'None.')"$'\nRepo: '"$repo"$'\nVerdict: accept')" ""
assert "that accept lets the diff commit" "$(gate 'git commit -am x')" ""
assert "a return with a finding records nothing to say" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: return')" ""
assert "that return clears the accept" "$(gate 'git commit -am x')" "$DENIED"
record_handback "$(report "$repo" accept)" >/dev/null
assert "a return without the sections on the second stop still clears the accept" \
  "$(record_handback $'Bad.\nRepo: '"$repo"$'\nVerdict: return' true; gate 'git commit -am x')" "$DENIED"

assert "a verdict in the last message counts when there is no handback" "$(record_last_message "$(report "$repo" accept)")" ""
assert "that verdict lets the diff commit" "$(gate 'git commit -am x')" ""

transcript="$scratch/late.jsonl"
stop_on() {
  jq -cn --arg cwd "$repo" --arg transcript "$transcript" --arg message "${1:-}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", cwd: $cwd, agent_transcript_path: $transcript, last_assistant_message: $message, stop_hook_active: false}' | "$RECORD" 2>/dev/null
}
record_late() {
  (sleep 0.5 && handback_line "$1" >>"$transcript") &
  stop_on
  wait
}

record_handback "$(report "$repo" return)" >/dev/null
read_line >"$transcript"
assert "a handback written to the transcript after the stop fires still counts" "$(record_late "$(report "$repo" accept)")" ""
assert "that late accept lets the diff commit" "$(gate 'git commit -am x')" ""

record_handback "$(report "$repo" return)" >/dev/null
{ handback_line "$(report "$repo" return)" && read_line; } >"$transcript"
record_late "$(report "$repo" accept)" >/dev/null
assert "a late accept after a re-review is not read as the earlier return" "$(gate 'git commit -am x')" ""

record_handback "$(report "$repo" accept)" >/dev/null
{ handback_line "$(report "$repo" accept)" && jq -cn '{type: "attachment", attachment: {type: "hook_blocking_error"}}'; } >"$transcript"
record_late "$(report "$repo" return)" >/dev/null
assert "a late return on the stop after a block is not read as the earlier accept" "$(gate 'git commit -am x')" "$DENIED"

record_handback "$(report "$repo" accept)" >/dev/null
{ handback_line "$(report "$repo" accept)" && jq -cn '{type: "user", message: {content: "Look again."}}'; } >"$transcript"
record_late "$(report "$repo" return)" >/dev/null
assert "a late return after a resume is not read as the earlier accept" "$(gate 'git commit -am x')" "$DENIED"

{ handback_line "$(report "$repo" accept)" && text_line 'Looking again.'; } >"$transcript"
assert "a text stop after an accepting handback is judged by the text alone" "$(stop_on 'Looking again.')" "$MISSING"

land
edit README.md 'more docs'
assert "a Markdown-only change commits without a verdict" "$(gate 'git commit -am docs')" ""
land
(cd "$repo" && git mv app.py app.md)
assert "a staged move of code to Markdown needs a verdict" "$(gate 'git commit -m x')" "$DENIED"
(cd "$repo" && git mv app.md app.py)

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
mismatch="$(jq -cn --arg reason "The report cites files in '$(cd "$worktree" && pwd -P)', another worktree of '$repo', and none in '$repo'. Put the path of the worktree the change is in on the 'Repo:' line, not another checkout of its repository." '{decision: "block", reason: $reason}')"
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
  "$(jq -cn --arg reason "'$repo' has more than one verdict. Give each repository one verdict: name it in one 'Repo:' line only." '{decision: "block", reason: $reason}')"
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
  "$(jq -cn --arg reason "'relative' is not an absolute path. Put 'Repo: <absolute path of the repository under review>' on the line above the verdict." '{decision: "block", reason: $reason}')"
assert "a second pair naming no repository keeps the reviewer running" \
  "$(record_handback "$(two_repos "$worktree" accept "$scratch/nowhere" accept)")" \
  "{\"decision\":\"block\",\"reason\":\"'$scratch/nowhere' is not a repository. Put 'Repo: <absolute path of the repository under review>' on the line above the verdict.\"}"

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

assert "recording a verdict without plugin data fails" \
  "$(printf '{"last_assistant_message":""}' | env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null 2>&1; echo "$?")" 1
assert "recording a verdict without plugin data names the script and the variable" \
  "$(printf '{"last_assistant_message":""}' | { env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null; } 2>&1)" "review-record.sh: CLAUDE_PLUGIN_DATA is required"

assert "the verdict recorder listens to the reviewer agent" "$(grep -c '"matcher": "^cniska-skills:reviewer$"' "$HERE/hooks.json")" 1

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
  jq -cn --arg cwd "$logged" --arg message "$1" --arg active "${2:-false}" \
    '{session_id: "s1", agent_id: "r1", hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", cwd: $cwd, last_assistant_message: $message, stop_hook_active: ($active == "true")}' | "$RECORD" 2>/dev/null
}

lines() { if [ -f "$log" ]; then wc -l <"$log" | tr -d ' '; else echo 0; fi; }
new_lines() { tail -n +"$(($1 + 1))" "$log" 2>/dev/null; }

decided() {
  local before
  before="$(lines)"
  "$@" >/dev/null
  new_lines "$before" | jq -c 'del(.ts, .v, .session, .agent, .cwd, .event)'
}

fingerprint_of() { (source "$HERE/review-state.sh" && diff_fingerprint "$1"); }

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
  "$(jq -cn --arg repo "$logged_repo" --arg fp "$fp" '{verdict: "accept", repo: $repo, fingerprint: $fp, reason: null}')"
assert "the verdict line names the reviewer's agent id" "$(tail -n 1 "$log" | jq -r .agent)" r1
assert "the accepted commit logs an allow with the same fingerprint" \
  "$(decided gate_logged 'git commit -am x')" \
  "$(jq -cn --arg repo "$logged_repo" --arg head "$logged_head" --arg fp "$fp" '{gate: "commit", decision: "allow", reason: "accepted", repo: $repo, head: $head, fingerprint: $fp}')"
(cd "$logged" && printf 'n = 3\n' >n.py)
assert "an edit after the accept logs changed_since_accept" "$(decided gate_logged 'git commit -am x' | jq -r .reason)" changed_since_accept
assert "a returning verdict logs the return" "$(decided record_logged "$(report "$logged" return)" | jq -r --arg repo "$logged_repo" '[.verdict, .repo == $repo] | @tsv')" "return	true"
assert "a commit after a return logs not_accepted" "$(decided gate_logged 'git commit -am x' | jq -r .reason)" not_accepted

(cd "$logged" && git checkout -q n.py && printf 'more\n' >>NOTES.md)
assert "a Markdown-only commit logs an allow" "$(decided gate_logged 'git commit -am x' | jq -c '[.decision, .reason, .fingerprint]')" '["allow","no_code_change",null]'
assert "a commit outside any repository logs an allow" "$(decided gate_logged 'git commit -am x' "$scratch" | jq -c '[.decision, .reason, .repo]')" '["allow","outside_repo",null]'
assert "two commits in one command log multiple_commits" "$(decided gate_logged 'git commit -m x && git commit -m y' | jq -r .reason)" multiple_commits
assert "a commit that creates its repo logs repo_created" "$(decided gate_logged 'git init -q && git commit -m x' | jq -r .reason)" repo_created
assert "a commit reaching its repo unclearly logs repo_unclear" "$(decided gate_logged '(cd ~/project && git commit -am x)' | jq -r .reason)" repo_unclear
assert "a commit naming no repository logs repo_not_found" "$(decided gate_logged 'cd ~/nowhere && git commit -am x' | jq -r .reason)" repo_not_found
assert "a gate that fails logs gate_error" "$(decided sh -c "printf 'not json' | '$GATE' 2>/dev/null" | jq -r '[.decision, .reason] | @tsv')" "deny	gate_error"

assert "a report with no verdict logs a deny" "$(decided record_logged 'No verdict.' | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	missing_verdict"
assert "the second stop without a verdict logs an allow" "$(decided record_logged 'No verdict.' true | jq -r '[.decision, .reason] | @tsv')" "allow	missing_verdict"
assert "a report with no Repo line logs missing_repo" "$(decided record_logged $'Fine.\nVerdict: accept' | jq -r .reason)" missing_repo
assert "a relative Repo path logs repo_relative" "$(decided record_logged "$(report logged accept)" | jq -r .reason)" repo_relative
assert "a report without the sections logs missing_findings" "$(decided record_logged $'Fine.\nRepo: '"$logged"$'\nVerdict: return' | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	missing_findings"
assert "an accept with a finding logs accept_with_findings" "$(decided record_logged "$(sections "$(finding)")"$'\nRepo: '"$logged"$'\nVerdict: accept' | jq -r .reason)" accept_with_findings
assert "a return for a brief with no diff logs reason no_diff" "$(decided record_logged "$(sections)"$'\nReason: no_diff\nRepo: '"$logged"$'\nVerdict: return' | jq -r '[.verdict, .reason] | @tsv')" "return	no_diff"
assert "a no_diff return beside an accept for another repo logs the reason on its own pair only" \
  "$(decided record_logged "$(sections)"$'\nReason: no_diff\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$other"$'\nVerdict: accept' | jq -sc 'map(.reason)')" '["no_diff",null]'
assert "a verdict with no Reason line logs a null reason" "$(decided record_logged "$(report "$logged" return)" | jq -c .reason)" null
assert "two pairs naming one repository log repo_repeated" "$(decided record_logged "$(sections)"$'\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$logged"$'\nVerdict: accept' | jq -r .reason)" repo_repeated
assert "a Repo path that is not a repository logs repo_not_found" "$(decided record_logged "$(report "$scratch/nowhere" accept)" | jq -r .reason)" repo_not_found

(cd "$logged" && git checkout -q NOTES.md && printf 'n = 4\n' >n.py)
mv "$log" "$log.kept"
mkdir "$log"
assert "an unwritable log leaves a deny unchanged" "$(gate_logged 'git commit -am x')" "$DENIED"
assert "an unwritable log leaves the deny's exit code at 0" "$(gate_logged 'git commit -am x' >/dev/null; echo "$?")" 0
assert "an unwritable log warns on stderr" \
  "$(jq -cn --arg cwd "$logged" '{tool_input: {command: "git commit -am x"}, cwd: $cwd}' | { "$GATE" >/dev/null; } 2>&1 | grep -c '^commit-gate.sh: the event log was not written')" 1
assert "an unwritable log still records an accept" "$(record_logged "$(report "$logged" accept)")" ""
assert "an unwritable log leaves an allow unchanged" "$(gate_logged 'git commit -am x')" ""
rmdir "$log"
mv "$log.kept" "$log"
assert "every logged line is one JSON object" "$(jq -s 'all(type == "object")' "$log")" true
assert "every line of a kind has the same fields" "$(jq -s 'group_by(.event) | all(map(keys) | unique | length == 1)' "$log")" true

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
