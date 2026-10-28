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

scratch="$(mktemp -d)" || exit 1
scratch="$(cd "$scratch" && pwd -P)" || exit 1
trap 'rm -rf "$scratch"' EXIT
source "$HERE/jq-past-shims.test-harness.sh"
link_jq_past_shims "$scratch"
export HOME="$scratch/home" CLAUDE_PROJECT_DIR="$scratch/project"
export GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$scratch"
unset XDG_DATA_HOME XDG_STATE_HOME AGENT_LEDGER
require_jq
mkdir -p "$HOME" "$CLAUDE_PROJECT_DIR"
default="$HOME/.local/share/agent-skills/${CLAUDE_PROJECT_DIR//\//-}/ledger.toon"

run() { "$HOOK" </dev/null 2>/dev/null; }
code() {
  "$HOOK" </dev/null >/dev/null 2>&1
  echo "$?"
}
write_ledger() {
  mkdir -p "${1%/*}"
  printf '%s\n' "$2" >"$1"
}
path_fn() { bash -c 'source "$1"; "$2"' _ "$HERE/ledger-path.sh" "$1"; }

assert "no ledger names the path it would be read from" "$(run)" "No ledger yet: a coordinating session creates it at $default"
assert "no ledger exits 0" "$(code)" 0

write_ledger "$HOME/.local/state/agent-skills/ledger.md" "old state ledger"
write_ledger "$HOME/.local/share/agent-skills/ledger.md" "old top-level ledger"
assert "the old top-level ledgers are not read" "$(run)" "No ledger yet: a coordinating session creates it at $default"

write_ledger "${default%.toon}.md" "old default ledger"
assert "the old markdown default is not read" "$(run)" "No ledger yet: a coordinating session creates it at $default"

write_ledger "$default" "default ledger"
assert "the default path is the project's folder under HOME's .local/share" "$(run)" "default ledger"
assert "a printed ledger exits 0" "$(code)" 0

write_ledger "$scratch/data/agent-skills/${CLAUDE_PROJECT_DIR//\//-}/ledger.toon" "xdg ledger"
assert "an absolute XDG_DATA_HOME holds the ledger" "$(XDG_DATA_HOME="$scratch/data" run)" "xdg ledger"
assert "a relative XDG_DATA_HOME falls back to HOME" "$(XDG_DATA_HOME="data" run)" "default ledger"
assert "an empty XDG_DATA_HOME falls back to HOME" "$(XDG_DATA_HOME="" run)" "default ledger"
assert "XDG_STATE_HOME no longer moves the ledger" "$(XDG_STATE_HOME="$scratch/data" run)" "default ledger"

write_ledger "$scratch/repo/ledger.md" "override ledger"
assert "AGENT_LEDGER overrides the project path" "$(AGENT_LEDGER="$scratch/repo/ledger.md" XDG_DATA_HOME="$scratch/data" run)" "override ledger"
assert "AGENT_LEDGER naming a missing file names it" "$(AGENT_LEDGER="$scratch/missing.md" run)" "No ledger yet: a coordinating session creates it at $scratch/missing.md"
assert "AGENT_LEDGER naming a missing file exits 0" "$(AGENT_LEDGER="$scratch/missing.md" code)" 0
assert "an empty AGENT_LEDGER uses the project path" "$(AGENT_LEDGER="" run)" "default ledger"

real_home="$(
  unset HOME
  printf '%s' ~
)"
assert "a blank HOME falls back to the account's home" \
  "$(HOME="  " path_fn ledger_path)" "$real_home/.local/share/agent-skills/${CLAUDE_PROJECT_DIR//\//-}/ledger.toon"

mkdir -p "$scratch/a" "$scratch/b"
assert "two project dirs resolve to two ledgers" \
  "$(CLAUDE_PROJECT_DIR="$scratch/a" path_fn ledger_path) $(CLAUDE_PROJECT_DIR="$scratch/b" path_fn ledger_path)" \
  "$HOME/.local/share/agent-skills/${scratch//\//-}-a/ledger.toon $HOME/.local/share/agent-skills/${scratch//\//-}-b/ledger.toon"
assert "without CLAUDE_PROJECT_DIR the working directory is the project" \
  "$(cd "$scratch/a" && unset CLAUDE_PROJECT_DIR && path_fn ledger_path)" \
  "$HOME/.local/share/agent-skills/${scratch//\//-}-a/ledger.toon"
ln -s "$scratch/a" "$scratch/a-link"
assert "a non-git dir resolves by its own real path" \
  "$(CLAUDE_PROJECT_DIR="$scratch/a-link" path_fn ledger_path)" "$HOME/.local/share/agent-skills/${scratch//\//-}-a/ledger.toon"

git init -q -b main "$scratch/main"
git -C "$scratch/main" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$scratch/main" worktree add -q "$scratch/linked" 2>/dev/null
mkdir -p "$scratch/main/sub"
main_ledger="$HOME/.local/share/agent-skills/${scratch//\//-}-main/ledger.toon"
assert "a repo resolves by its top level from a subdirectory" "$(CLAUDE_PROJECT_DIR="$scratch/main/sub" path_fn ledger_path)" "$main_ledger"
assert "a linked worktree resolves to its main checkout's ledger" "$(CLAUDE_PROJECT_DIR="$scratch/linked" path_fn ledger_path)" "$main_ledger"

git init -q --bare -b main "$scratch/x.git"
git init -q --bare -b main "$scratch/y.git"
git --git-dir="$scratch/x.git" -c user.name=t -c user.email=t@example.com commit-tree -m init "$(git --git-dir="$scratch/x.git" mktree </dev/null)" >"$scratch/x-root"
git --git-dir="$scratch/x.git" update-ref refs/heads/main "$(cat "$scratch/x-root")"
git --git-dir="$scratch/x.git" worktree add -q "$scratch/x-work" main 2>/dev/null
assert "bare repos side by side resolve to two ledgers" \
  "$(CLAUDE_PROJECT_DIR="$scratch/x.git" path_fn ledger_path) $(CLAUDE_PROJECT_DIR="$scratch/y.git" path_fn ledger_path)" \
  "$HOME/.local/share/agent-skills/${scratch//\//-}-x.git/ledger.toon $HOME/.local/share/agent-skills/${scratch//\//-}-y.git/ledger.toon"
assert "a bare repo's worktree resolves to the bare repo's ledger" \
  "$(CLAUDE_PROJECT_DIR="$scratch/x-work" path_fn ledger_path)" "$HOME/.local/share/agent-skills/${scratch//\//-}-x.git/ledger.toon"

git -C "$scratch/main" -c protocol.file.allow=always -c user.name=t -c user.email=t@example.com submodule -q add "$scratch/main" mod 2>/dev/null
assert "a submodule resolves to a ledger of its own" \
  "$(CLAUDE_PROJECT_DIR="$scratch/main/mod" path_fn ledger_path)" "$HOME/.local/share/agent-skills/${scratch//\//-}-main-.git-modules-mod/ledger.toon"

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset AGENT_LEDGER XDG_DATA_HOME GIT_SSH_COMMAND

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
  "Ledger not pulled: its branch tracks no remote branch, so the remote may hold a newer copy.

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

write_ledger "$scratch/split/ledger.toon" "shared rules"
write_ledger "$scratch/split/ledgers/loop.toon" "shared: ../ledger.toon
choices[1]{project,choice,reason}:
  loop,a choice,a reason"
assert "a TOON ledger with a shared key prints the shared file after it" \
  "$(AGENT_LEDGER="$scratch/split/ledgers/loop.toon" run)" "shared: ../ledger.toon
choices[1]{project,choice,reason}:
  loop,a choice,a reason

shared rules"

write_ledger "$scratch/absolute/ledger.toon" "name: loop
shared: \"$scratch/split/ledger.toon\""
assert "a quoted absolute shared path names the shared file" \
  "$(AGENT_LEDGER="$scratch/absolute/ledger.toon" run)" "name: loop
shared: \"$scratch/split/ledger.toon\"

shared rules"

write_ledger "$scratch/commented/ledger.toon" "# notes
shared: ../split/ledger.toon"
assert "a full-line comment, which TOON drops on decode, leaves the shared key read" \
  "$(AGENT_LEDGER="$scratch/commented/ledger.toon" run)" "# notes
shared: ../split/ledger.toon

shared rules"

write_ledger "$scratch/alone/ledger.toon" "name: loop
plans[1]{project,plan,where}:
  loop,shared,../split/ledger.toon
meta:
  shared: ../split/ledger.toon"
assert "a TOON ledger with no root shared key prints alone" \
  "$(AGENT_LEDGER="$scratch/alone/ledger.toon" run)" "name: loop
plans[1]{project,plan,where}:
  loop,shared,../split/ledger.toon
meta:
  shared: ../split/ledger.toon"

write_ledger "$scratch/markdown/ledger.md" "[Shared](../split/ledger.toon)
loop ledger"
assert "a markdown ledger linking a shared file prints alone" \
  "$(AGENT_LEDGER="$scratch/markdown/ledger.md" run)" "[Shared](../split/ledger.toon)
loop ledger"

write_ledger "$scratch/prose/ledger.md" "Notes on the loop
shared: ../split/ledger.toon"
assert "a file that does not decode as TOON names no shared file" \
  "$(AGENT_LEDGER="$scratch/prose/ledger.md" run)" "Notes on the loop
shared: ../split/ledger.toon"

write_ledger "$scratch/indented/ledger.toon" "shared: ../split/ledger.toon
  stray"
assert "an indented line under a value does not decode and names no shared file" \
  "$(AGENT_LEDGER="$scratch/indented/ledger.toon" run)" "shared: ../split/ledger.toon
  stray"

write_ledger "$scratch/twice/ledger.toon" "shared: ../split/ledger.toon
shared: ../split/ledger.toon"
assert "a duplicate root key does not decode and names no shared file" \
  "$(AGENT_LEDGER="$scratch/twice/ledger.toon" run)" "shared: ../split/ledger.toon
shared: ../split/ledger.toon"

write_ledger "$scratch/number/ledger.toon" "shared: 12"
assert "a shared key that is not a string names no shared file" "$(AGENT_LEDGER="$scratch/number/ledger.toon" run)" "shared: 12"

write_ledger "$scratch/self/ledger.toon" "shared: ledger.toon"
assert "a ledger naming itself as shared prints once" "$(AGENT_LEDGER="$scratch/self/ledger.toon" run)" "shared: ledger.toon"

write_ledger "$scratch/broken/ledgers/loop.toon" "shared: ../ledger.toon"
assert "a shared file that is missing is named" \
  "$(AGENT_LEDGER="$scratch/broken/ledgers/loop.toon" run)" "shared: ../ledger.toon

Shared file not found: $scratch/broken/ledgers/../ledger.toon"
assert "a missing shared file exits 0" "$(AGENT_LEDGER="$scratch/broken/ledgers/loop.toon" code)" 0

mkdir -p "$scratch/failing-jq"
printf '#!/bin/sh\nexit 1\n' >"$scratch/failing-jq/jq"
chmod +x "$scratch/failing-jq/jq"
assert "a jq that cannot run says the shared file was not read" \
  "$(PATH="$scratch/failing-jq:$PATH" AGENT_LEDGER="$scratch/split/ledgers/loop.toon" run)" "shared: ../ledger.toon
choices[1]{project,choice,reason}:
  loop,a choice,a reason

Shared file not read: jq could not run on the ledger."
assert "a jq that cannot run still exits 0" \
  "$(PATH="$scratch/failing-jq:$PATH" AGENT_LEDGER="$scratch/split/ledgers/loop.toon" code)" 0

commit_split() {
  mkdir -p "$1/ledgers"
  printf 'shared: ../ledger.toon\nnote: %s\n' "$2" >"$1/ledgers/loop.toon"
  printf '%s\n' "$3" >"$1/ledger.toon"
  git -C "$1" add ledgers/loop.toon ledger.toon
  git -C "$1" commit -qm "$2"
}

split_repo() {
  local root="$scratch/$1"
  git init -q --bare -b main "$root/remote.git"
  git clone -q "$root/remote.git" "$root/ledger" 2>/dev/null
  commit_split "$root/ledger" "old loop" "old rules"
  git -C "$root/ledger" push -q origin main 2>/dev/null
  git clone -q "$root/remote.git" "$root/other" 2>/dev/null
  commit_split "$root/other" "new loop" "new rules"
  git -C "$root/other" push -q origin main 2>/dev/null
  printf '%s\n' "$root/ledger"
}

repo="$(split_repo split-repo)"
assert "a shared file in the ledger's repo is pulled with it" \
  "$(AGENT_LEDGER="$repo/ledgers/loop.toon" run)" "shared: ../ledger.toon
note: new loop

new rules"

repo="$(split_repo split-offline)"
git -C "$repo" remote set-url origin "$scratch/split-offline/missing.git"
assert "a shared file in the ledger's unpulled repo is not fetched again" \
  "$(AGENT_LEDGER="$repo/ledgers/loop.toon" run)" "Ledger not pulled: could not fetch origin/main; it is at least 0 commits behind as of the last fetch.

shared: ../ledger.toon
note: old loop

old rules"

repo="$(split_repo split-untracked)"
printf 'shared: ../ledger.toon\nnote: fresh loop\n' >"$repo/ledgers/fresh.toon"
assert "an untracked ledger still has its repo's shared file pulled" \
  "$(AGENT_LEDGER="$repo/ledgers/fresh.toon" run)" "shared: ../ledger.toon
note: fresh loop

new rules"

shared="$(setup_ledger_repo shared-clean)"
write_ledger "$scratch/own/ledger.toon" "shared: $shared/ledger.md"
assert "a shared file in another repo is pulled the same way" \
  "$(AGENT_LEDGER="$scratch/own/ledger.toon" run)" "shared: $shared/ledger.md

new ledger"

shared="$(setup_ledger_repo shared-dirty)"
printf 'edited\n' >>"$shared/notes.md"
write_ledger "$scratch/own-dirty/ledger.toon" "shared: $shared/ledger.md"
assert "a shared file that could not be pulled says so under its own name" \
  "$(AGENT_LEDGER="$scratch/own-dirty/ledger.toon" run)" "shared: $shared/ledger.md

Shared file not pulled: its repo has uncommitted changes; it is 1 commits behind origin/main.

old ledger"

shared="$(setup_ledger_repo shared-local)"
git -C "$shared" branch -q --unset-upstream
write_ledger "$scratch/own-local/ledger.toon" "shared: $shared/ledger.md"
assert "a shared file with no upstream says the remote may be newer under its own name" \
  "$(AGENT_LEDGER="$scratch/own-local/ledger.toon" run)" "shared: $shared/ledger.md

Shared file not pulled: its branch tracks no remote branch, so the remote may hold a newer copy.

old ledger"

hooks="$HERE/hooks.json"
runs_ledger() {
  jq -r --arg event "$1" '[.hooks[$event][] | any(.hooks[]; .command | endswith("/hooks/ledger.sh"))] | all' "$hooks"
}
assert "every SessionStart group runs the ledger hook" "$(runs_ledger SessionStart)" true
assert "no PostCompact hook runs the ledger" \
  "$(jq -r '[.hooks.PostCompact[]?.hooks[] | .command | endswith("/hooks/ledger.sh")] | any' "$hooks")" false

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
