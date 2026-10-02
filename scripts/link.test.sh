#!/usr/bin/env bash
# Unit tests for link.sh against a throwaway skills directory.
# Run: ./link.test.sh  (exit 0 = all pass, 1 = failures)
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LINK="$HERE/link.sh"
REPO_SKILLS="$(cd "$HERE/../skills" && pwd)"

pass=0
fail=0
assert() { # desc got want
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

target="$(mktemp -d)"
trap 'rm -rf "$target"' EXIT
run() { SKILLS_DIR="$target" "$LINK" "$@" >/dev/null 2>&1; echo "$?"; }

assert "named skill links"         "$(run review)" 0
assert "link points at the repo"   "$(readlink "$target/review")" "$REPO_SKILLS/review"
assert "relinking is a no-op"      "$(run review)" 0
assert "unknown skill fails"       "$(run no-such-skill)" 1

mkdir "$target/writing"
assert "existing folder is kept"   "$(run writing)" 1
assert "folder left untouched"     "$([ -L "$target/writing" ] && echo link || echo dir)" dir

ln -s "$REPO_SKILLS/renamed-away" "$target/renamed-away"
ln -s /elsewhere/missing "$target/foreign"
run >/dev/null
assert "dangling repo link removed"  "$([ -L "$target/renamed-away" ] && echo kept || echo gone)" gone
assert "foreign link left alone"     "$([ -L "$target/foreign" ] && echo kept || echo gone)" kept
assert "every skill linked"          "$([ -L "$target/audit" ] && echo yes || echo no)" yes

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
