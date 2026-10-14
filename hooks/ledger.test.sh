#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/ledger.sh"

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
export HOME="$scratch/home"
unset XDG_STATE_HOME AGENT_LEDGER
mkdir -p "$HOME"

run() { "$HOOK" </dev/null 2>/dev/null; }
code() {
  "$HOOK" </dev/null >/dev/null 2>&1
  echo "$?"
}
write_ledger() {
  mkdir -p "${1%/*}"
  printf '%s\n' "$2" >"$1"
}

assert "no ledger at the default path prints nothing" "$(run)" ""
assert "no ledger exits 0" "$(code)" 0

write_ledger "$HOME/.local/state/agent-skills/ledger.md" "default ledger"
assert "the default path is under HOME's .local/state" "$(run)" "default ledger"
assert "a printed ledger exits 0" "$(code)" 0

write_ledger "$scratch/state/agent-skills/ledger.md" "xdg ledger"
assert "an absolute XDG_STATE_HOME holds the ledger" "$(XDG_STATE_HOME="$scratch/state" run)" "xdg ledger"
assert "a relative XDG_STATE_HOME falls back to HOME" "$(XDG_STATE_HOME="state" run)" "default ledger"
assert "an empty XDG_STATE_HOME falls back to HOME" "$(XDG_STATE_HOME="" run)" "default ledger"
assert "an XDG_STATE_HOME with no ledger prints nothing" "$(XDG_STATE_HOME="$scratch/empty" run)" ""

write_ledger "$scratch/repo/ledger.md" "override ledger"
assert "AGENT_LEDGER overrides the XDG path" "$(AGENT_LEDGER="$scratch/repo/ledger.md" XDG_STATE_HOME="$scratch/state" run)" "override ledger"
assert "AGENT_LEDGER naming a missing file prints nothing" "$(AGENT_LEDGER="$scratch/missing.md" run)" ""
assert "AGENT_LEDGER naming a missing file exits 0" "$(AGENT_LEDGER="$scratch/missing.md" code)" 0
assert "an empty AGENT_LEDGER uses the XDG path" "$(AGENT_LEDGER="" run)" "default ledger"

real_home="$(
  unset HOME
  printf '%s' ~
)"
assert "a blank HOME falls back to the account's home" \
  "$(HOME="  " bash -c 'source "$1"; ledger_path' _ "$HERE/ledger-path.sh")" "$real_home/.local/state/agent-skills/ledger.md"

hooks="$HERE/hooks.json"
runs_ledger() {
  jq -r --arg event "$1" '[.hooks[$event][] | any(.hooks[]; .command | endswith("/hooks/ledger.sh"))] | all' "$hooks"
}
assert "every SessionStart group runs the ledger hook" "$(runs_ledger SessionStart)" true
assert "every PostCompact group runs the ledger hook" "$(runs_ledger PostCompact)" true

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
