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
assert "resume sends the session to the Resume route" \
  "$(run resume | grep -c 'Load the cniska-skills:task skill again and take its Resume route')" 1
assert "start exits 0" "$(code start)" 0
assert "resume exits 0" "$(code resume)" 0
assert "no argument is a usage error" "$(code)" 2
assert "unknown argument is a usage error" "$(code compact)" 2
assert "usage error prints nothing on stdout" "$(run bogus)" ""

hooks="$HERE/hooks.json"
assert "startup and clear run the start context" "$(grep -c '"matcher": "startup|clear"' "$hooks")" 1
assert "resume, compact and fork run the resume context" "$(grep -c '"matcher": "resume|compact|fork"' "$hooks")" 1
assert "hooks call the script with start" "$(grep -c 'hooks/session-start.sh start"' "$hooks")" 1
assert "hooks call the script with resume" "$(grep -c 'hooks/session-start.sh resume"' "$hooks")" 1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
