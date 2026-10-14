#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/session-start.sh"

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

run() { "$HOOK" "$@" 2>/dev/null; }
code() { "$HOOK" "$@" >/dev/null 2>&1; echo "$?"; }

assert "start tells the session to load task first" \
  "$(run start | grep -c 'Start each task with the cniska-skills:task skill, loaded with the Skill tool, and')" 1
assert "start leaves the other skills to task" \
  "$(run start | grep -c 'load other skills only as it, or a skill it loads, directs.')" 1
assert "start says commits wait on the reviewer" \
  "$(run start | grep -c 'waits until cniska-skills:reviewer has accepted the diff')" 1
assert "resume sends the session back into its route" \
  "$(run resume | grep -c "otherwise load the cniska-skills:task skill again and re-enter the work's route")" 1
assert "resume sends no task session to a Resume" "$(run resume | grep -c 'cniska-skills:task[^;]*Resume')" 0
assert "resume sends a coordinating session to coordinate" \
  "$(run resume | grep -c "When this session coordinates other agents, load the cniska-skills:coordinate skill again and resume its ledger and workers as that skill's Resume section says")" 1
assert "start exits 0" "$(code start)" 0
assert "resume exits 0" "$(code resume)" 0
assert "no argument is a usage error" "$(code)" 2
assert "unknown argument is a usage error" "$(code compact)" 2
assert "usage error prints nothing on stdout" "$(run bogus)" ""

hooks="$HERE/hooks.json"
matcher_commands() {
  jq -r --arg matcher "$1" '[.hooks.SessionStart[] | select(.matcher == $matcher) | .hooks[].command | sub("^.*/hooks/"; "")] | join(", ")' "$hooks"
}
assert "SessionStart matches startup|clear, resume|fork and compact" \
  "$(jq -r '[.hooks.SessionStart[].matcher] | join(" ")' "$hooks")" "startup|clear resume|fork compact"
assert "startup and clear run the start context and the ledger" "$(matcher_commands 'startup|clear')" \
  "session-start.sh start, ledger.sh"
assert "resume and fork run the resume context and the ledger" "$(matcher_commands 'resume|fork')" \
  "session-start.sh resume, ledger.sh"
assert "compact runs only the ledger, with no reload line" "$(matcher_commands compact)" "ledger.sh"
assert "hooks call the script with start" "$(grep -c 'hooks/session-start.sh start"' "$hooks")" 1
assert "hooks call the script with resume" "$(grep -c 'hooks/session-start.sh resume"' "$hooks")" 1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
