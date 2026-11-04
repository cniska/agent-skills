#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

readonly RULING_TOOL=mcp__plugin_cniska-skills_report__ruling
readonly REASONS='[{"rule": "Size everything to the need", "reason": "Already fixed in the second diff."}]'

top="$(cd "$repo" && git rev-parse --show-toplevel)"
decision() { jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$1"; }
why() { jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$1"; }
tags() { jq -sc '[.[] | select(.event == "tag")] | map([.key, .value, .agent])' "$log"; }
last_gate() { jq -sc '[.[] | select(.event == "gate")] | last | [.gate, .decision, .reason]' "$log"; }

ruling_by() {
  local caller="$1" payload="$2" transcript="${3:-}"
  jq -cn --arg tool "$RULING_TOOL" --arg cwd "$repo" --argjson caller "$caller" --argjson payload "$payload" --arg transcript "$transcript" '
    {hook_event_name: "PreToolUse", session_id: "s0", cwd: $cwd, tool_name: $tool, tool_input: $payload}
    + $caller + (if $transcript == "" then {} else {transcript_path: $transcript} end)' | "$RECORD" 2>/dev/null
}

session_that_read() { scratch_file "$(read_of "$1")"; }
written_diff() { scratch_file "$(diff_of "$(report "$1" accept)")"; }

work_right() {
  jq -cn --arg repo "${2:-$repo}" --arg diff "$1" --argjson findings "$REASONS" \
    '{repo: $repo, review: "commit", call: "work_right", diffs: [$diff], findings: $findings}'
}
owner_call() {
  jq -cn --arg repo "$repo" --arg call "$1" --arg diff "$2" \
    '{repo: $repo, review: "commit", call: $call, diffs: [$diff], owner_words: "It is just a spike anyway."}'
}

edit app.py 'print(2)'
diff="$(written_diff "$repo")"
session="$(session_that_read "$diff")"
payload="$(work_right "$diff")"

for caller in '{"agent_id": "sub1"}' '{"agent_id": "sub2", "agent_type": "general-purpose"}' \
  '{"agent_type": "cniska-skills:worker"}' '{"agent_type": "cniska-skills:reviewer"}' \
  '{"agent_type": "cniska-skills:designer"}' '{"agent_type": "cniska-skills:researcher"}'; do
  out="$(ruling_by "$caller" "$payload" "$session")"
  assert "a ruling from $caller is refused" "$(decision "$out")" deny
  assert "that refusal is wrong_agent" "$(last_gate)" '["verdict","deny","wrong_agent"]'
  out="$(ruling_by "$caller" "$payload" "$session")"
  assert "a second ruling from $caller is refused too, with no bound" "$(decision "$out")" deny
  assert "that refusal lets no commit through" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
done
assert "a refused ruling logs no ruling" "$(tags)" '[]'

assert "a ruling on a diff the session did not read is refused" \
  "$(decision "$(ruling_by '{}' "$payload" "$(session_that_read /elsewhere.diff)")")" deny
assert "that refusal is diff_not_read" "$(last_gate)" '["verdict","deny","diff_not_read"]'
assert "with no transcript no diff counts as read" "$(decision "$(ruling_by '{}' "$payload")")" deny
assert "and the commit stays blocked" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

assert "work_right with no reason for a finding is refused" \
  "$(why "$(ruling_by '{}' "$(jq -c 'del(.findings)' <<<"$payload")" "$session")" | sed -n 2p)" '/findings is required when /call is "work_right"'
assert "that refusal is payload_invalid" "$(last_gate)" '["verdict","deny","payload_invalid"]'
assert "an empty list of reasons is refused" \
  "$(why "$(ruling_by '{}' "$(jq -c '.findings = []' <<<"$payload")" "$session")" | sed -n 2p)" '/findings must hold at least 1 item'
assert "a reason off the schema is refused" \
  "$(decision "$(ruling_by '{}' "$(jq -c '.findings[0].reason = ""' <<<"$payload")" "$session")")" deny
assert "a commit's accept with no diffs is refused" \
  "$(why "$(ruling_by '{}' "$(jq -c 'del(.diffs)' <<<"$payload")" "$session")" | sed -n 2p)" '/diffs must name each diff you read when the ruling accepts a commit'
assert "an unknown call is refused" "$(decision "$(ruling_by '{}' "$(jq -c '.call = "maybe"' <<<"$payload")" "$session")")" deny
assert "owner words on the coordinator's own call are refused" \
  "$(decision "$(ruling_by '{}' "$(jq -c '.owner_words = "go"' <<<"$payload")" "$session")")" deny
assert "the owner's call with no words is refused" \
  "$(decision "$(ruling_by '{}' "$(owner_call owner_decision "$diff" | jq -c 'del(.owner_words)')" "$session")")" deny
assert "an owner instruction outside a commit is refused" \
  "$(decision "$(ruling_by '{}' "$(owner_call owner_instruction "$diff" | jq -c '.review = "branch" | del(.diffs)')" "$session")")" deny
assert "no malformed ruling lets a commit through" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "not a repository is refused" "$(decision "$(ruling_by '{}' "$(work_right "$diff" "$scratch/home")" "$session")")" deny
assert "that refusal is repo_not_found" "$(last_gate)" '["verdict","deny","repo_not_found"]'

stale="$(scratch_file 'diff --git a/app.py b/app.py
index 0000000..1234567 100644')"
assert "a diff that no longer matches the change is refused" \
  "$(decision "$(ruling_by '{}' "$(work_right "$stale")" "$(session_that_read "$stale")")")" deny
assert "that refusal is accept_covers_nothing" "$(last_gate)" '["verdict","deny","accept_covers_nothing"]'

other="$scratch/linked"
git -C "$repo" worktree add -q -b linked "$other"
assert "a ruling naming the wrong worktree is refused" \
  "$(why "$(ruling_by '{}' "$(work_right "$diff" "$other")" "$session")")" \
  "None of app.py in the diff files you read matches what is staged or in the working tree of '$(cd "$other" && pwd -P)', so this accept would cover nothing; they match the worktree '$top'. Name the worktree the change is in as the judgment's repo, not another checkout of its repository."
assert "that refusal is worktree_mismatch" "$(last_gate)" '["verdict","deny","worktree_mismatch"]'
git -C "$repo" worktree remove --force "$other"
git -C "$repo" branch -q -D linked
assert "a refused ruling logs no ruling, whatever refused it" "$(tags)" '[]'

assert "a coordinator's ruling is allowed without a prompt" "$(ruling_by '{}' "$payload" "$session")" "$(allowed)"
assert "it logs a tag with its call and no verdict" "$(tags)" '[["ruling","work_right",null]]'
assert "a ruling writes no verdict line, so the commit reads as unreviewed" "$(jq -sc '[.[] | select(.event == "verdict")] | length' "$log")" 0
assert "a line never holds the reasons or the owner's words" "$(grep -c 'Already fixed\|just a spike' "$log")" 0
assert "the gate takes it like a reviewer's" "$(gate 'git commit -am x')" ""
assert "a later edit to the path needs an accept again" "$(edit app.py 'print(3)'; gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
(cd "$repo" && git checkout -q -- app.py)
edit app.py 'print(2)'
assert "a reviewer's return voids it as any accept" \
  "$(ruling_by '{}' "$payload" "$session" >/dev/null; record_handback "$(report "$repo" return ".findings = [$(finding "$top/app.py" 'Size everything to the need' major)]")" >/dev/null; gate 'git commit -am x')" \
  "$(denied 'app.py (working tree)')"
ruling_by '{}' "$payload" "$session" >/dev/null
land
(cd "$repo" && git show HEAD~1:app.py >app.py)
land
edit app.py 'print(2)'
assert "a ruled path's accept lapses once a commit touches it, though the content returns" \
  "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
(cd "$repo" && git checkout -q -- app.py)

for call in owner_instruction owner_decision; do
  edit app.py "print('$call')"
  own="$(written_diff "$repo")"
  assert "a session records $call on its own change, with no earlier return" \
    "$(ruling_by '{}' "$(owner_call "$call" "$own")" "$(session_that_read "$own")")" "$(allowed)"
  assert "the gate takes $call" "$(gate 'git commit -am x')" ""
  land
done

for review in branch designer plan; do
  edit app.py "print('$review')"
  ruled="$(jq -cn --arg repo "$repo" --arg review "$review" --argjson findings "$REASONS" '{repo: $repo, review: $review, call: "work_right", findings: $findings}')"
  assert "a $review ruling is allowed" "$(ruling_by '{}' "$ruled" "$session")" "$(allowed)"
  assert "a $review ruling adds no paths to the gate" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
  assert "a $review ruling takes no diffs" \
    "$(decision "$(ruling_by '{}' "$(jq -c --arg diff "$diff" '.diffs = [$diff]' <<<"$ruled")" "$session")")" deny
  (cd "$repo" && git checkout -q -- app.py)
done

edit app.py 'print(9)'
for call in finding_right owner_only; do
  assert "$call is on the record" "$(ruling_by '{}' "$(jq -cn --arg repo "$repo" --arg call "$call" '{repo: $repo, review: "commit", call: $call}')" "$session")" "$(allowed)"
  assert "$call adds no paths" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
done
assert "every ruling's call is on the record, in order" "$(tags | jq -c 'map(.[1]) | .[-5:]')" '["work_right","work_right","work_right","finding_right","owner_only"]'

finish
