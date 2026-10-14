#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORD="$HERE/coach-record.sh"
DUE="$HERE/coach-due.sh"

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
export CLAUDE_PLUGIN_DATA="$scratch/data"
export AGENT_LEDGER="$scratch/ledger/ledger.md"
upstreams="$scratch/ledger/upstreams.json"
mkdir -p "$scratch/ledger"
last_run="$CLAUDE_PLUGIN_DATA/coach/last-run"

readonly MISSING='{"decision":"block","reason":"End your report with a last line that is exactly '"'"'Proposals: <n>'"'"', counting the proposals other than one-offs."}'
readonly DUE_NEVER="The coach is due. At the next break, run cniska-skills:coach over the past week's sessions, then apply its proposals except conflicts, which go to the owner."

record_handback() {
  local transcript="$scratch/transcript.jsonl"
  jq -cn --arg message "$1" '{type: "assistant", message: {content: [{type: "tool_use", name: "SubagentHandback", input: {message: $message}}]}}' >"$transcript"
  jq -cn --arg transcript "$transcript" --arg active "${2:-false}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:coach", agent_transcript_path: $transcript, last_assistant_message: "", stop_hook_active: ($active == "true")}' | "$RECORD" 2>/dev/null
}

record_last_message() {
  jq -cn --arg message "$1" --arg active "${2:-false}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:coach", last_assistant_message: $message, stop_hook_active: ($active == "true")}' | "$RECORD" 2>/dev/null
}

readonly SESSION_START='{"hook_event_name":"SessionStart","source":"startup"}'
due() { printf '%s' "$SESSION_START" | "$DUE" 2>/dev/null; }
due_code() {
  printf '%s' "$SESSION_START" | "$DUE" >/dev/null 2>&1
  echo "$?"
}
due_stderr() { printf '%s' "$SESSION_START" | { "$DUE" >/dev/null; } 2>&1; }
recorded() { if [ -f "$last_run" ]; then echo yes; else echo no; fi; }

assert "a report with no Proposals line keeps the coach running" "$(record_last_message 'Nothing much.')" "$MISSING"
assert "a Proposals count that is not a number keeps the coach running" "$(record_last_message $'Done.\nProposals: some')" "$MISSING"
assert "a Proposals line not on its own line does not count" "$(record_last_message 'My Proposals: 2')" "$MISSING"
assert "a missing Proposals line records no run" "$(recorded)" no
assert "a missing Proposals line on the second stop lets the coach stop" "$(record_last_message 'Still none.' true)" ""
assert "a coach stopped without a Proposals line records no run" "$(recorded)" no

before="$(date +%s)"
assert "a good report in the last message says nothing" "$(record_last_message $'Two things.\nProposals: 2')" ""
after="$(date +%s)"
assert "a good report in the last message records the run" "$(recorded)" yes
stamp="$(cat "$last_run" 2>/dev/null)"
assert "the record holds the current epoch seconds" "$([[ $stamp =~ ^[0-9]+$ ]] && ((stamp >= before && stamp <= after)) && echo yes)" yes

rm -f "$last_run"
assert "a good report in a handback says nothing" "$(record_handback $'Nothing clears the bar.\nProposals: 0')" ""
assert "a good report in a handback records the run" "$(recorded)" yes
rm -f "$last_run"
assert "a handback with no Proposals line keeps the coach running" "$(record_handback 'Forgot the count.')" "$MISSING"
assert "a handback with no Proposals line records no run" "$(recorded)" no

assert "recording without plugin data fails" \
  "$(printf '{"last_assistant_message":"Proposals: 1"}' | env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null 2>&1; echo "$?")" 1

assert "with no record the coach is due over the past week" "$(due)" "$DUE_NEVER"
assert "a due coach exits 0" "$(due_code)" 0

record_last_message 'Proposals: 1' >/dev/null
assert "right after a run the coach is not due" "$(due)" ""

printf '%s\n' 1700000000 >"$last_run"
assert "a run older than a day makes the coach due since that run" "$(due)" \
  "The coach is due. At the next break, run cniska-skills:coach over the sessions since 2023-11-14T22:13:20Z, then apply its proposals except conflicts, which go to the owner."

printf '%s\n' $(($(date +%s) - 86400 + 60)) >"$last_run"
assert "a run just under a day old is not due" "$(due)" ""

printf 'not a time\n' >"$last_run"
assert "a garbage record counts as never run" "$(due)" "$DUE_NEVER"
assert "a garbage record exits 0" "$(due_code)" 0

: >"$last_run"
assert "an empty record counts as never run" "$(due)" "$DUE_NEVER"

rm -f "$last_run"
mkdir -p "$last_run"
assert "an unreadable record prints nothing" "$(due)" ""
assert "an unreadable record fails without blocking the session" "$(due_code)" 1
assert "an unreadable record warns on stderr" "$(due_stderr | grep -c '^coach-due.sh: .*cannot be read')" 1
rmdir "$last_run"

fake_bin="$scratch/bin"
mkdir -p "$fake_bin"
real_date="$(command -v date)"
cat >"$fake_bin/date" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do case "\$a" in -d|-r) exit 1 ;; esac; done
exec "$real_date" "\$@"
EOF
chmod +x "$fake_bin/date"
printf '%s\n' 1700000000 >"$last_run"
assert "a date that cannot be formatted prints nothing" "$(PATH="$fake_bin:$PATH" due)" ""
assert "a date that cannot be formatted fails without blocking the session" "$(PATH="$fake_bin:$PATH" due_code)" 1
assert "a date that cannot be formatted warns on stderr" "$(PATH="$fake_bin:$PATH" due_stderr | grep -c '^coach-due.sh: .*cannot be formatted')" 1
rm -f "$last_run"

assert "no plugin data prints nothing" "$(printf '{}' | env -u CLAUDE_PLUGIN_DATA "$DUE" 2>/dev/null)" ""
assert "no plugin data fails without blocking the session" "$(printf '{}' | env -u CLAUDE_PLUGIN_DATA "$DUE" >/dev/null 2>&1; echo "$?")" 1
assert "no plugin data warns on stderr" "$(printf '{}' | { env -u CLAUDE_PLUGIN_DATA "$DUE" >/dev/null; } 2>&1 | grep -c '^coach-due.sh: CLAUDE_PLUGIN_DATA is not set')" 1

git_bin="$scratch/git-bin"
git_calls="$scratch/git-calls"
mkdir -p "$git_bin"
cat >"$git_bin/git" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$git_calls"
[ "\$1" = ls-remote ] || exit 2
case "\$2" in
  https://github.com/a/moved) printf '%s\tHEAD\n' bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ;;
  https://github.com/b/still) printf '%s\tHEAD\n' cccccccccccccccccccccccccccccccccccccccc ;;
  https://github.com/c/moved) printf '%s\tHEAD\n' dddddddddddddddddddddddddddddddddddddddd ;;
  https://github.com/s/stalled) exec sleep 30 ;;
  *) exit 128 ;;
esac
EOF
chmod +x "$git_bin/git"
git_due() { PATH="$git_bin:$PATH" due; }
calls() { if [ -f "$git_calls" ]; then wc -l <"$git_calls" | tr -d ' '; else echo 0; fi; }
readonly A_OLD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
readonly C_HEAD=cccccccccccccccccccccccccccccccccccccccc
readonly MOVED_NOTE="Upstreams moved since their last review"

assert "with no upstream list the due note stands alone" "$(git_due)" "$DUE_NEVER"
assert "with no upstream list no remote is asked" "$(calls)" 0

jq -n --arg a "$A_OLD" --arg c "$C_HEAD" '[
  {repo: "a/moved", path: "skills/", taken: "x", reviewed: $a},
  {repo: "b/still", taken: "y", reviewed: $c},
  {repo: "x/gone", taken: "z", reviewed: $a},
  {repo: "c/moved", taken: "w", reviewed: $a}
]' >"$upstreams"
assert "a due coach counts the upstreams that moved among those that answered" "$(git_due)" \
  "$DUE_NEVER"$'\n'"$MOVED_NOTE: 2 of the 3 that answered."
assert "each upstream's remote is asked for its head" "$(grep -c '^ls-remote https://github.com/[^ ]* HEAD$' "$git_calls")" 4
assert "counting upstreams writes nothing to stderr" "$(PATH="$git_bin:$PATH" due_stderr)" ""

rm -f "$git_calls"
record_last_message 'Proposals: 1' >/dev/null
assert "a coach that is not due says nothing about upstreams" "$(git_due)" ""
assert "a coach that is not due asks no remote" "$(calls)" 0
rm -f "$last_run"

jq -n --arg c "$C_HEAD" '[{repo: "b/still", taken: "y", reviewed: $c}]' >"$upstreams"
assert "upstreams that have not moved add nothing" "$(git_due)" "$DUE_NEVER"

jq -n --arg a "$A_OLD" '[{repo: "x/gone", taken: "z", reviewed: $a}]' >"$upstreams"
assert "an unreachable upstream is skipped silently" "$(git_due)" "$DUE_NEVER"

jq -n --arg a "$A_OLD" '[{repo: "--upload-pack=evil", taken: "z", reviewed: $a}, {repo: "a/moved", taken: "x", reviewed: $a}]' >"$upstreams"
rm -f "$git_calls"
assert "an entry whose repo is not owner/name is skipped" "$(git_due)" \
  "$DUE_NEVER"$'\n'"$MOVED_NOTE: 1 of the 1 that answered."
assert "a skipped entry asks no remote" "$(calls)" 1

jq -n --arg a "$A_OLD" '[{repo: "s/stalled", taken: "s", reviewed: $a}, {repo: "a/moved", taken: "x", reviewed: $a}]' >"$upstreams"
started="$(date +%s)"
stalled_output="$(printf '%s' "$SESSION_START" | PATH="$git_bin:$PATH" "$DUE" 2>"$scratch/stalled-stderr")"
elapsed=$(($(date +%s) - started))
assert "a stalled upstream is dropped at the deadline and the rest still count" "$stalled_output" \
  "$DUE_NEVER"$'\n'"$MOVED_NOTE: 1 of the 1 that answered."
assert "a stalled upstream holds the session start no longer than the deadline" "$([ "$elapsed" -le 8 ] && echo yes || echo "no, ${elapsed}s")" yes
assert "a stalled upstream writes nothing to stderr" "$(cat "$scratch/stalled-stderr")" ""

printf 'not json\n' >"$upstreams"
assert "an unreadable upstream list still says the coach is due" "$(git_due)" "$DUE_NEVER"
assert "an unreadable upstream list exits 0" "$(PATH="$git_bin:$PATH" due_code)" 0
assert "an unreadable upstream list warns on stderr" "$(PATH="$git_bin:$PATH" due_stderr | grep -c '^coach-due.sh: .*upstream count is skipped')" 1
rm -f "$upstreams" "$git_calls"

hooks="$HERE/hooks.json"
assert "the run recorder listens to the coach agent" \
  "$(jq -r '.hooks.SubagentStop[] | select(.matcher == "^cniska-skills:coach$") | .hooks[].command' "$hooks")" "\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/coach-record.sh"
assert "startup and clear check whether the coach is due" \
  "$(jq -r '.hooks.SessionStart[] | select(.matcher == "startup|clear") | .hooks[].command' "$hooks" | grep -c 'hooks/coach-due.sh$')" 1
assert "resume does not check whether the coach is due" \
  "$(jq -r '.hooks.SessionStart[] | select(.matcher != "startup|clear") | .hooks[].command' "$hooks" | grep -c 'coach-due')" 0

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
