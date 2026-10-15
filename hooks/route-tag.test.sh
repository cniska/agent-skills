#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
export CLAUDE_PLUGIN_DATA="$scratch/data"
log="$CLAUDE_PLUGIN_DATA/events.jsonl"
ROOT="$scratch/plugin"
HOOK="$ROOT/hooks/route-tag.sh"
mkdir -p "$ROOT/hooks" "$ROOT/skills/workflow/task/references/x" "$ROOT/skills/expertise/code-writing/references"
cp "$HERE/route-tag.sh" "$HERE/event-log.sh" "$ROOT/hooks/"
for file in workflow/task/references/feature.md workflow/task/references/bug-fix.md workflow/task/references/review.md \
  workflow/task/references/x/feature.md workflow/task/SKILL.md expertise/code-writing/references/shell.md; do
  printf '# Doc\n' >"$ROOT/skills/$file"
done

read_file() {
  jq -cn --arg path "$1" \
    '{session_id: "s1", agent_id: "a1", cwd: "/work", hook_event_name: "PostToolUse", tool_name: "Read", tool_input: {file_path: $path}}' | "$HOOK"
}

lines() { if [ -f "$log" ]; then wc -l <"$log" | tr -d ' '; else echo 0; fi; }
tagged() {
  local before
  before="$(lines)"
  read_file "$1" >/dev/null 2>&1
  tail -n +"$((before + 1))" "$log" 2>/dev/null | jq -r .value
}

assert "reading a route prints nothing" "$(read_file "$ROOT/skills/workflow/task/references/feature.md" 2>&1)" ""
assert "reading a route tags the task with the route" "$(tail -n 1 "$log" | jq -c 'del(.ts)')" \
  '{"v":1,"event":"tag","session":"s1","agent":"a1","cwd":"/work","key":"route","value":"feature"}'
assert "the tag is stamped to the second in UTC" \
  "$(tail -n 1 "$log" | jq -r '.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")')" true
assert "each route file tags its own stem" "$(tagged "$ROOT/skills/workflow/task/references/bug-fix.md")" bug-fix
assert "a path through the plugin's own parent folder still tags" \
  "$(tagged "$ROOT/skills/workflow/../workflow/task/references/review.md")" review
assert "the task skill itself tags nothing" "$(tagged "$ROOT/skills/workflow/task/SKILL.md")" ""
assert "another skill's references tag nothing" \
  "$(tagged "$ROOT/skills/expertise/code-writing/references/shell.md")" ""
assert "a route-shaped path nested deeper tags nothing" \
  "$(tagged "$ROOT/skills/workflow/task/references/x/feature.md")" ""
assert "another install's route tags nothing" \
  "$(tagged "$(cd "$HERE/.." && pwd)/skills/workflow/task/references/feature.md")" ""
assert "a path in no folder that exists tags nothing" "$(tagged "$scratch/missing/task/references/feature.md")" ""
assert "a call with no file path tags nothing and exits 0" \
  "$(printf '{"tool_name":"Read"}' | "$HOOK" >/dev/null 2>&1; echo "$?") $(lines)" "0 3"
assert "input that is not JSON exits 0" "$(printf 'nope' | "$HOOK" >/dev/null 2>&1; echo "$?")" 0

mv "$log" "$log.kept"
mkdir "$log"
assert "an unwritable log still exits 0" "$(read_file "$ROOT/skills/workflow/task/references/feature.md" >/dev/null 2>&1; echo "$?")" 0
assert "an unwritable log warns on stderr" \
  "$(read_file "$ROOT/skills/workflow/task/references/feature.md" 2>&1 >/dev/null | grep -c '^route-tag.sh: the event log was not written')" 1
rmdir "$log"
mv "$log.kept" "$log"

assert "every line is one JSON object" "$(jq -s 'all(type == "object")' "$log")" true
assert "the hook runs after every Read" \
  "$(jq -r '.hooks.PostToolUse[] | select(.matcher == "Read") | .hooks[].command' "$HERE/hooks.json")" \
  "\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/route-tag.sh"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
