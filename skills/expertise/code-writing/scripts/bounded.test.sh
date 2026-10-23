#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOUNDED="$HERE/bounded"
REAL_SLEEP="$(command -v sleep)"

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

tmp=""
run=""
status=""

fresh() {
  tmp="$(mktemp -d "$scratch/case.XXXXXX")"
  mkdir "$tmp/bin"
  printf '%s\n' '#!/bin/sh' "echo \$\$ >>\"$tmp/timer\"" "exec \"$REAL_SLEEP\" \"\$@\"" >"$tmp/bin/sleep"
  chmod +x "$tmp/bin/sleep"
}

launch() {
  set -m
  PATH="$tmp/bin:$PATH" "$BOUNDED" "$@" </dev/null >"$tmp/out" 2>"$tmp/err" &
  run=$!
  set +m
}

launch_captured() {
  set -m
  (
    out="$(PATH="$tmp/bin:$PATH" "$BOUNDED" "$@" 2>"$tmp/err")"
    printf '%s\n' "$?" >"$tmp/status"
    printf '%s' "$out" >"$tmp/out"
  ) </dev/null >/dev/null 2>&1 &
  run=$!
  set +m
}

running() { kill -0 "$run" 2>/dev/null; }

finished_within() {
  local label="$1" limit="$2" i
  for ((i = 0; i < limit * 10; i++)); do
    running || break
    sleep 0.1
  done
  if running; then
    fail=$((fail + 1))
    printf 'FAIL %s finished within %ss\n  got:  still running\n' "$label" "$limit"
    kill -KILL -- -"$run" 2>/dev/null
    [ ! -s "$tmp/pgid" ] || kill -KILL -- -"$(cat "$tmp/pgid")" 2>/dev/null
    wait "$run" 2>/dev/null
    status=""
    return 1
  fi
  pass=$((pass + 1))
  wait "$run"
  status=$?
}

pinned() {
  local i
  for ((i = 0; i < 30; i++)); do
    [ -s "$tmp/pgid" ] && return 0
    sleep 0.1
  done
  return 1
}

group_dead() {
  local pgid i
  pgid="$(cat "$tmp/pgid")"
  for ((i = 0; i < 10; i++)); do
    kill -0 -- -"$pgid" 2>/dev/null || return 0
    sleep 0.1
  done
  kill -KILL -- -"$pgid" 2>/dev/null
  return 1
}

group_state() { group_dead && echo dead || echo alive; }

timer_pids_gone() {
  local pid i
  while IFS= read -r pid; do
    for ((i = 0; i < 10; i++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -0 "$pid" 2>/dev/null && return 1
  done <"$tmp/timer"
  return 0
}

kill_timer_pids() {
  local pid
  while IFS= read -r pid; do
    kill -KILL "$pid" 2>/dev/null
  done <"$tmp/timer"
}

fresh
launch 30 sh -c 'exit 3'
finished_within "an exiting command" 3 && {
  assert "an exiting command's status passes through" "$status" 3
  assert "an exiting command leaves stderr empty" "$(<"$tmp/err")" ""
}

fresh
launch 30 sh -c 'echo $$ >"$1"; sleep 300 & exit 3' sh "$tmp/pgid"
finished_within "a command that leaves a child behind" 3 && {
  assert "a command that leaves a child behind still passes its status through" "$status" 3
  assert "a command's leftover child is ended on a normal exit" "$(group_state)" dead
}

fresh
launch 1 sh -c 'echo $$ >"$1"; sleep 300 & sleep 300' sh "$tmp/pgid"
finished_within "a command past its deadline" 3 && {
  assert "a command past its deadline reads as 124" "$status" 124
  assert "the deadline is reported on stderr" "$(<"$tmp/err")" "bounded: deadline: 1s"
  assert "the group is dead after the deadline" "$(group_state)" dead
}

fresh
launch 1 sh -c 'trap "" TERM; echo $$ >"$1"; sleep 300 & sleep 300' sh "$tmp/pgid"
finished_within "a TERM-ignoring command past its deadline" 5 && {
  assert "a TERM-ignoring command past its deadline reads as 124" "$status" 124
  assert "a TERM-ignoring group is killed after the deadline" "$(group_state)" dead
}

fresh
launch 1 sh -c 'echo $$ >"$1"; (trap "" TERM; exec sleep 300) & sleep 300' sh "$tmp/pgid"
finished_within "a command whose child ignores TERM past its deadline" 5 && {
  assert "a command whose child ignores TERM past its deadline reads as 124" "$status" 124
  assert "a TERM-ignoring child is killed after the deadline" "$(group_state)" dead
}

fresh
launch_captured 30 sh -c 'until [ -s "$1" ]; do :; done' sh "$tmp/timer"
finished_within "a caller reading through \$(...)" 3 && {
  assert "a caller reading through \$(...) gets the command's status" "$(<"$tmp/status")" 0
  assert "the timer ran sleep from PATH" "$([ -s "$tmp/timer" ] && echo logged || echo empty)" logged
  assert "the timer is gone once the command ends" "$(timer_pids_gone && echo gone || echo alive)" gone
}

fresh
launch_captured 30 sh -c 'until [ -s "$1" ]; do :; done; kill -KILL $PPID' sh "$tmp/timer"
finished_within "a caller reading through \$(...) when bounded is killed" 3
kill_timer_pids

signalled_by() {
  local signal="$1" code="$2"
  fresh
  launch 30 sh -c 'echo $$ >"$1"; sleep 300 & sleep 300' sh "$tmp/pgid"
  assert "the command had started before $signal was sent" "$(pinned && echo started || echo not-started)" started
  kill -"$signal" "$run"
  finished_within "bounded sent $signal" 3 && {
    assert "bounded sent $signal exits $code" "$status" "$code"
    assert "bounded sent $signal reports it on stderr" "$(<"$tmp/err")" "bounded: interrupted: $signal"
    assert "the group is dead after $signal" "$(group_state)" dead
  }
}
signalled_by TERM 143
signalled_by INT 130

fresh
launch abc true
finished_within "a non-numeric bound" 3 && {
  assert "a non-numeric bound is a usage error" "$status" 2
  assert "a usage error names the usage" "$(head -n 1 "$tmp/err")" "bounded: usage: bounded <seconds> <command> [args...]"
}

fresh
launch 5
finished_within "a missing command" 3 && {
  assert "a missing command is a usage error" "$status" 2
}

fresh
launch --help
finished_within "help" 3 && {
  assert "help exits 0" "$status" 0
  assert "help goes to stdout" "$(head -n 1 "$tmp/out")" "Usage: bounded <seconds> <command> [args...]"
}

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
