#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$HERE/lint-shell.sh"

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
export HOME="$scratch/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$scratch"
mkdir -p "$HOME"

repo() {
  mkdir -p "$scratch/$1"
  git -C "$scratch/$1" init -q
}
tracked() {
  cat >"$scratch/$1/$2"
  git -C "$scratch/$1" add "$2"
}
run() { (cd "$scratch/$1" && "$LINT" "${@:2}" >"$scratch/$1.out" 2>"$scratch/$1.err"; echo "$?"); }

repo mixed
tracked mixed tool <<'EOF'
#!/usr/bin/env bash
for f in $@; do printf '%s\n' "$f"; done
EOF
tracked mixed clean.sh <<'EOF'
#!/bin/sh
printf 'ok\n'
EOF
tracked mixed notes.md <<'EOF'
# Notes
for f in $@; do printf '%s\n' "$f"; done
EOF
assert "an extensionless shell file with an error fails the lint" "$([ "$(run mixed)" -ne 0 ] && echo failed || echo passed)" failed
assert "the failing extensionless file is named" "$(grep -c '^In tool line' "$scratch/mixed.out")" 1
assert "a non-shell file is not linted" "$(grep -c 'notes.md' "$scratch/mixed.out")" 0

repo clean
tracked clean run.sh <<'EOF'
#!/bin/sh
printf 'ok\n'
EOF
tracked clean tool <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
assert "clean shell files pass" "$(run clean)" 0

repo empty
tracked empty notes.md <<<'# Notes'
assert "no tracked shell file exits 1" "$(run empty)" 1
assert "no tracked shell file says so" "$(<"$scratch/empty.err")" "lint-shell.sh: no tracked shell file under $(cd "$scratch/empty" && pwd)"

mkdir -p "$scratch/outside"
assert "a directory that is no repository exits 1" "$(run outside)" 1
assert "a directory that is no repository says so" "$(<"$scratch/outside.err")" "lint-shell.sh: git found no repository at $(cd "$scratch/outside" && pwd); run it inside the repository"

assert "an argument is a usage error" "$(run empty extra)" 2
assert "help exits 0" "$(run empty --help)" 0
assert "help goes to stdout" "$(head -n 1 "$scratch/empty.out")" "Usage: lint-shell.sh"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
