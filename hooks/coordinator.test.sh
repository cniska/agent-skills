#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/coordinator.sh"

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
require_jq
export HOME="$scratch/home" GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$scratch"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset AGENT_TASK_PROJECT GIT_SSH_COMMAND
mkdir -p "$HOME" "$scratch/stub"

cat >"$scratch/stub/agent-task" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  --version) printf '0.0.0\n' ;;
  "project list") cat "$STUB_PROJECTS" ;;
  "list --project loop --full") printf 'tasks of loop, update check %s\n' "${AGENT_TASK_NO_UPDATE_CHECK:-on}" ;;
  "list --project "*) printf 'error:\n  code: unknown_project\n' >&2; exit 1 ;;
  *) exit 2 ;;
esac
STUB
chmod +x "$scratch/stub/agent-task"
export PATH="$scratch/stub:$PATH" STUB_PROJECTS="$scratch/projects.toon"

projects() {
  printf 'command: project\nok: true\nresult:\n  counts:\n    projects: 2\n  projects[2]{id,name,repo,dir}:\n    other,Other,/repo,/elsewhere\n    loop,"Loop, the agents",/repo,"%s"\n' "$1" >"$STUB_PROJECTS"
}

run() { "$HOOK" </dev/null 2>/dev/null; }
code() {
  "$HOOK" </dev/null >/dev/null 2>&1
  echo "$?"
}

commands="This session coordinates the agent-task project loop, and its tasks are its state. Read them with \`agent-task list --project loop --full\`. Queue one with \`agent-task add <name> --project loop --repo <path> --goal <text>\`, giving its plan with \`--plan <file>\` and what it waits on with \`--waits <text>\`. Start one with \`agent-task start <name> --project loop --repo <path> --brief <file>\`, change what one waits on with \`agent-task wait <name> --waits <text>\`, and close one with \`agent-task done <name>\`."
tasks="tasks of loop, update check 1"

assert "no project id prints nothing" "$(run)" ""
assert "no project id exits 0" "$(code)" 0
assert "a blank project id prints nothing" "$(AGENT_TASK_PROJECT="  " run)" ""

export AGENT_TASK_PROJECT=loop

assert "a project whose directory is missing names it, then prints its tasks" \
  "$(projects "$scratch/missing" && run)" "$commands

Project directory $scratch/missing not pulled: it does not exist.

$tasks"

mkdir -p "$scratch/plain"
assert "a project directory outside git is named and its tasks still print" \
  "$(projects "$scratch/plain" && run)" "$commands

Project directory $scratch/plain not pulled: it is not a git checkout.

$tasks"

printf 'command: project\nok: true\nresult:\n  counts:\n    projects: 0\n  projects[0]{id,name,repo,dir}:\n' >"$STUB_PROJECTS"
assert "a project the store lacks names no directory and prints the refusal" \
  "$(AGENT_TASK_PROJECT=gone run)" "${commands//loop/gone}

Project directory not pulled: agent-task project list names no directory for gone.

error:
  code: unknown_project"
assert "a project the store lacks exits 0" "$(AGENT_TASK_PROJECT=gone code)" 0

printf 'result:\n  projects[1]{id,name,dir}:\n    loop,Loop,"%s"\n' "$scratch/plain" >"$STUB_PROJECTS"
assert "a table without the four expected fields names no directory" \
  "$(run | grep -c '^Project directory not pulled: agent-task project list names no directory for loop.')" 1

assert "without agent-task the tasks are not read" \
  "$(PATH="$(dirname "$(command -v jq)"):/usr/bin:/bin" run)" "$commands

Tasks not read: agent-task is not on PATH or does not run."

mkdir -p "$scratch/failing-jq"
printf '#!/bin/sh\nexit 1\n' >"$scratch/failing-jq/jq"
chmod +x "$scratch/failing-jq/jq"
projects "$scratch/plain"
assert "a jq that cannot run says the list could not be read, and the tasks still print" \
  "$(PATH="$scratch/failing-jq:$PATH" run)" "$commands

Project directory not pulled: agent-task project list could not be read with jq.

$tasks"

printf '#!/usr/bin/env bash\n[ "$*" = "project list" ] && exit 3\nexec "%s" "$@"\n' "$scratch/stub/agent-task" >"$scratch/failing-jq/agent-task"
chmod +x "$scratch/failing-jq/agent-task"
assert "a refused project list says it could not be read, and the tasks still print" \
  "$(PATH="$scratch/failing-jq:$PATH" run | grep -c '^Project directory not pulled: agent-task project list could not be read')" 1

commit_file() {
  printf '%s\n' "$2" >"$1/state.md"
  git -C "$1" add state.md
  git -C "$1" commit -qm "$2"
}

project_repo() {
  local root="$scratch/$1"
  git init -q --bare -b main "$root/remote.git"
  git clone -q "$root/remote.git" "$root/dir" 2>/dev/null
  commit_file "$root/dir" "old"
  git -C "$root/dir" push -q origin main 2>/dev/null
  git clone -q "$root/remote.git" "$root/other" 2>/dev/null
  commit_file "$root/other" "new"
  git -C "$root/other" push -q origin main 2>/dev/null
  projects "$root/dir"
  printf '%s\n' "$root/dir"
}

repo="$(project_repo clean)"
assert "a clean directory behind its remote is pulled before the tasks print" "$(run)" "$commands

$tasks"
assert "the pull fast-forwards the directory" "$(cat "$repo/state.md")" "new"
assert "an up-to-date directory prints with no note" "$(run)" "$commands

$tasks"

repo="$(project_repo comma,dir)"
assert "a quoted directory holding the delimiter is pulled" "$(run >/dev/null && cat "$repo/state.md")" "new"

repo="$(project_repo dirty)"
printf 'edited\n' >>"$repo/state.md"
assert "a dirty directory is not pulled and says how far behind" "$(run)" "$commands

Project directory $repo not pulled: it has uncommitted changes; it is 1 commits behind origin/main.

$tasks"

repo="$(project_repo diverged)"
commit_file "$repo" "local"
assert "a diverged directory is not pulled and says so" "$(run)" "$commands

Project directory $repo not pulled: its branch has diverged from origin/main; it is 1 commits behind and 1 ahead.

$tasks"

repo="$(project_repo offline)"
git -C "$repo" remote set-url origin "$scratch/offline/missing.git"
assert "an unreachable remote is named and the tasks still print" "$(run)" "$commands

Project directory $repo not pulled: could not fetch origin/main; it is at least 0 commits behind as of the last fetch.

$tasks"

repo="$(project_repo local)"
git -C "$repo" branch -q --unset-upstream
assert "a branch with no upstream says the remote may be newer" "$(run)" "$commands

Project directory $repo not pulled: its branch tracks no remote branch, so the remote may hold newer work.

$tasks"

repo="$(project_repo pruned)"
git -C "$repo" config fetch.prune true
git -C "$scratch/pruned/remote.git" branch -q -m main moved
assert "an upstream the fetch prunes is named and the tasks still print" "$(run)" "$commands

Project directory $repo not pulled: after fetching, git could not compare it with origin/main.

$tasks"

repo="$(project_repo slow)"
git -C "$repo" remote set-url origin "ssh://coordinator.invalid/remote.git"
printf '#!/bin/sh\nsleep 20\n' >"$scratch/slow-ssh"
chmod +x "$scratch/slow-ssh"
started="$(date +%s)"
slow="$(GIT_SSH="$scratch/slow-ssh" "$HOOK" </dev/null 2>"$scratch/slow-stderr")"
assert "a fetch past the deadline is stopped and named" "$slow" "$commands

Project directory $repo not pulled: fetching origin/main took over 5s; it is at least 0 commits behind as of the last fetch.

$tasks"
assert "a fetch past the deadline returns within it" "$((($(date +%s) - started) <= 8))" 1
assert "a fetch past the deadline writes nothing to stderr" "$(cat "$scratch/slow-stderr")" ""
assert "a fetch past the deadline leaves no transport running" "$(pgrep -f "$scratch/slow-ssh" | wc -l | tr -d ' ')" 0

hooks="$HERE/hooks.json"
assert "every SessionStart group runs the coordinator hook" \
  "$(jq -r '[.hooks.SessionStart[] | any(.hooks[]; .command | endswith("/hooks/coordinator.sh"))] | all' "$hooks")" true

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
