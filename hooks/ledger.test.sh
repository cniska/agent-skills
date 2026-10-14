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

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset AGENT_LEDGER XDG_STATE_HOME GIT_SSH_COMMAND

commit_ledger() {
  printf '%s\n' "$2" >"$1/ledger.md"
  git -C "$1" add ledger.md
  git -C "$1" commit -qm "$2"
}

setup_ledger_repo() {
  local root="$scratch/$1"
  git init -q --bare -b main "$root/remote.git"
  git clone -q "$root/remote.git" "$root/ledger" 2>/dev/null
  commit_ledger "$root/ledger" "old ledger"
  printf 'notes\n' >"$root/ledger/notes.md"
  git -C "$root/ledger" add notes.md
  git -C "$root/ledger" commit -qm notes
  git -C "$root/ledger" push -q origin main 2>/dev/null
  git clone -q "$root/remote.git" "$root/other" 2>/dev/null
  commit_ledger "$root/other" "new ledger"
  git -C "$root/other" push -q origin main 2>/dev/null
  printf '%s\n' "$root/ledger"
}

run_in() { AGENT_LEDGER="$1/ledger.md" "$HOOK" </dev/null 2>/dev/null; }

repo="$(setup_ledger_repo clean)"
assert "a clean ledger checkout behind its remote is pulled first" "$(run_in "$repo")" "new ledger"
assert "an up-to-date ledger prints with no note" "$(run_in "$repo")" "new ledger"

repo="$(setup_ledger_repo dirty)"
printf 'edited\n' >>"$repo/notes.md"
assert "a dirty ledger checkout is not pulled and says how far behind" "$(run_in "$repo")" \
  "Ledger not pulled: its repo has uncommitted changes; it is 1 commits behind origin/main.

old ledger"

repo="$(setup_ledger_repo diverged)"
commit_ledger "$repo" "local ledger"
assert "a diverged ledger branch is not pulled and says so" "$(run_in "$repo")" \
  "Ledger not pulled: its branch has diverged from origin/main; it is 1 commits behind and 1 ahead.

local ledger"

repo="$(setup_ledger_repo offline)"
git -C "$repo" remote set-url origin "$scratch/offline/missing.git"
assert "an unreachable remote is named and the ledger still prints" "$(run_in "$repo")" \
  "Ledger not pulled: could not fetch origin/main; it is at least 0 commits behind as of the last fetch.

old ledger"

repo="$(setup_ledger_repo slow)"
git -C "$repo" remote set-url origin "ssh://ledger.invalid/remote.git"
printf '#!/bin/sh\nsleep 20\n' >"$scratch/slow-ssh"
chmod +x "$scratch/slow-ssh"
started="$(date +%s)"
slow="$(GIT_SSH="$scratch/slow-ssh" AGENT_LEDGER="$repo/ledger.md" "$HOOK" </dev/null 2>"$scratch/slow-stderr")"
assert "a fetch past the deadline is stopped and named" "$slow" \
  "Ledger not pulled: fetching origin/main took over 5s; it is at least 0 commits behind as of the last fetch.

old ledger"
assert "a fetch past the deadline returns within it" "$((($(date +%s) - started) <= 8))" 1
assert "a fetch past the deadline writes nothing to stderr" "$(cat "$scratch/slow-stderr")" ""
assert "a fetch past the deadline leaves no transport running" "$(pgrep -f "$scratch/slow-ssh" | wc -l | tr -d ' ')" 0

repo="$(setup_ledger_repo local)"
git -C "$repo" branch -q --unset-upstream
assert "a branch with no upstream says the remote may be newer" "$(run_in "$repo")" \
  "Ledger not pulled: its branch tracks no remote branch, so the remote may hold a newer ledger.

old ledger"

repo="$(setup_ledger_repo pruned)"
git -C "$repo" config fetch.prune true
git -C "$scratch/pruned/remote.git" branch -q -m main moved
assert "an upstream the fetch prunes is named and the ledger still prints" "$(run_in "$repo")" \
  "Ledger not pulled: after fetching, git could not compare it with origin/main.

old ledger"

git init -q "$scratch/untracked"
printf 'untracked ledger\n' >"$scratch/untracked/ledger.md"
assert "a ledger git does not track prints with no pull" "$(run_in "$scratch/untracked")" "untracked ledger"

hooks="$HERE/hooks.json"
runs_ledger() {
  jq -r --arg event "$1" '[.hooks[$event][] | any(.hooks[]; .command | endswith("/hooks/ledger.sh"))] | all' "$hooks"
}
assert "every SessionStart group runs the ledger hook" "$(runs_ledger SessionStart)" true
assert "every PostCompact group runs the ledger hook" "$(runs_ledger PostCompact)" true

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
