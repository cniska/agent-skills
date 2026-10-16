#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$HERE/test-shell.sh"

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

fixture() {
  mkdir -p "$(dirname "$scratch/$1/$2")"
  cat >"$scratch/$1/$2"
}
run() { (cd "$scratch/$1" && "$RUNNER" "${@:2}" >"$scratch/$1.out" 2>"$scratch/$1.err"; echo "$?"); }

fixture mixed a.test.sh <<'EOF'
for n in 1 2 3; do echo "a $n"; sleep 0.2; done
EOF
fixture mixed b.test.sh <<'EOF'
for n in 1 2 3; do echo "b $n"; sleep 0.2; done
echo "b broke" >&2
exit 1
EOF
fixture mixed node_modules/dep/c.test.sh <<<'echo "dependency test ran"; exit 1'
fixture mixed .claude/d.test.sh <<<'echo "local test ran"; exit 1'
assert "a failing file exits 1" "$(run mixed)" 1
assert "each file's output prints whole under its name, in sorted order" "$(<"$scratch/mixed.out")" "== ./a.test.sh ==
a 1
a 2
a 3
== ./b.test.sh ==
b 1
b 2
b 3
b broke"
assert "the failing file is named on stderr" "$(<"$scratch/mixed.err")" "test-shell.sh: failed: ./b.test.sh"

fixture parallel a.test.sh <<'EOF'
for _ in $(seq 50); do [ -e ../b.ran ] && exit 0; sleep 0.1; done
echo "b never started while a ran"
exit 1
EOF
fixture parallel b.test.sh <<<'touch ../b.ran'
assert "files run at once" "$(run parallel)" 0
assert "a passing run says nothing on stderr" "$(<"$scratch/parallel.err")" ""

fixture failing a.test.sh <<<'exit 3'
fixture failing b.test.sh <<<'exit 0'
fixture failing c.test.sh <<<'exit 1'
assert "every file runs past a failure" "$(run failing)" 1
assert "every failing file is named" "$(<"$scratch/failing.err")" "test-shell.sh: failed: ./a.test.sh
test-shell.sh: failed: ./c.test.sh"

fixture stdin a.test.sh <<<'cat; echo read-done'
assert "a test reading stdin gets end of input" "$(run stdin)" 0
assert "a test reading stdin reads nothing" "$(<"$scratch/stdin.out")" "== ./a.test.sh ==
read-done"

stopped_by() {
  local signal="$1" code="$2" dir="$scratch/stopped-$1" runner child_pid status
  fixture "stopped-$signal" a.test.sh <<'EOF'
sleep 30 &
printf '%s\n' "$!" >../child.pid
wait
EOF
  rm -f "$scratch/child.pid"
  set -m
  (cd "$dir" && exec "$RUNNER" >/dev/null 2>&1) &
  runner=$!
  set +m
  for _ in $(seq 50); do
    [ -s "$scratch/child.pid" ] && break
    sleep 0.1
  done
  child_pid="$(cat "$scratch/child.pid" 2>/dev/null)"
  assert "a run stopped by $signal had started its test's child" "${child_pid:+started}" started
  kill -"$signal" "$runner"
  wait "$runner"
  status=$?
  assert "a run stopped by $signal exits $code" "$status" "$code"
  for _ in $(seq 50); do
    kill -0 "$child_pid" 2>/dev/null || break
    sleep 0.1
  done
  assert "stopping the run by $signal stops what its tests started" "$(kill -0 "$child_pid" 2>/dev/null && echo running || echo stopped)" stopped
  kill "$child_pid" 2>/dev/null
}
stopped_by TERM 143
stopped_by INT 130

mkdir -p "$scratch/empty"
assert "no test files exits 1" "$(run empty)" 1
assert "no test files says so" "$(<"$scratch/empty.err")" "test-shell.sh: no *.test.sh files under $(cd "$scratch/empty" && pwd)"

assert "an argument is a usage error" "$(run empty extra)" 2
assert "help exits 0" "$(run empty --help)" 0
assert "help goes to stdout" "$(head -n 1 "$scratch/empty.out")" "Usage: test-shell.sh"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
