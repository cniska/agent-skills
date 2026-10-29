#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

top="$(cd "$repo" && git rev-parse --show-toplevel)"
new_lines() { tail -n +"$(($1 + 1))" "$log"; }
lines() { wc -l <"$log" | tr -d ' '; }
returns_after() {
  local agent
  agent="$(fresh_agent)"
  record_as "$agent" "$1" >/dev/null
  stored "$agent" | jq -c '.gate.judgments | map(.returns_on_commit)'
}

edit app.py 'print(2)'
first="$(fresh_agent)"
assert "a first return off the schema keeps its reviewer running" \
  "$(record_as "$first" "$(report "$repo" return 'del(.clean)')" | jq -r .hookSpecificOutput.permissionDecision)" deny
record_as "$first" "$(report "$repo" return)" >/dev/null
assert "that reviewer's fixed first return counts one return" "$(stored "$first" | jq -c '.gate.judgments | map(.returns_on_commit)')" '[1]'
assert "a second return on the same commit counts two, so the denied pass counted once" "$(returns_after "$(report "$repo" return)")" '[2]'
edit app.py 'print(3)'
assert "an accept between returns records no count" "$(returns_after "$(report "$repo" accept)")" '[0]'
assert "that accept lets the change commit" "$(gate 'git commit -am x')" ""

before="$(lines)"
returner="$(fresh_agent)"
assert "a third return on the same commit is allowed" "$(record_as "$returner" "$(report "$repo" return)")" "$(allowed)"
assert "its record counts three returns on the commit" "$(stored "$returner" | jq -c '.gate.judgments[0] | [.repo, .verdict, .recorded, .returns_on_commit]')" \
  "$(jq -cn --arg repo "$top" '[$repo, "return", true, 3]')"
assert "the third return logs its verdict and no gate line" \
  "$(new_lines "$before" | jq -sc 'map([.event, .verdict, .repo, .agent])')" "$(jq -cn --arg repo "$top" --arg agent "$returner" '[["verdict", "return", $repo, $agent]]')"
assert "the third return voids the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a fourth return counts four" "$(returns_after "$(report "$repo" return)")" '[4]'
assert "an accept after the third return records as any accept" "$(record_handback "$(report "$repo" accept)")" "$(allowed)"
assert "that accept lets the commit land" "$(gate 'git commit -am x')" ""

land
edit app.py 'print(4)'
assert "a commit that lands starts the count over" "$(returns_after "$(report "$repo" return)")" '[1]'
assert "a second return on the new commit counts two" "$(returns_after "$(report "$repo" return)")" '[2]'

(cd "$repo" && git checkout -q -- app.py)
edit README.md 'other change'
assert "a change replaced by one on other paths starts the count over" "$(returns_after "$(report "$repo" return)")" '[1]'

finish
