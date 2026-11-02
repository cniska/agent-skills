#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

top="$(cd "$repo" && git rev-parse --show-toplevel)"
new_lines() { tail -n +"$(($1 + 1))" "$log"; }
lines() { wc -l <"$log" | tr -d ' '; }
counts() { stored "$1" | jq -c '.gate.judgments | map(.finding_returns_on_commit)'; }
returns_after() {
  local agent
  agent="$(fresh_agent)"
  record_as "$agent" "$1" >/dev/null
  counts "$agent"
}
returning() {
  local found rule
  found="$(for rule in "${@:2}"; do finding "$top/$1" "$rule"; done | jq -sc .)"
  report "$repo" return ".findings = $found"
}

edit app.py 'print(2)'
first="$(fresh_agent)"
assert "a first return off the schema keeps its reviewer running" \
  "$(record_as "$first" "$(returning app.py 'No dead structure' | jq -c 'del(.clean)')" | jq -r .hookSpecificOutput.permissionDecision)" deny
record_as "$first" "$(returning app.py 'No dead structure')" >/dev/null
assert "that reviewer's fixed first return counts its finding once" "$(counts "$first")" '[1]'
assert "a second return with a new finding counts one" "$(returns_after "$(returning app.py 'Parse at the boundary')")" '[1]'
assert "a third return with a new finding counts one, so new findings keep the work going" \
  "$(returns_after "$(returning app.py 'One empty value')")" '[1]'
assert "the same rule on another path is a new finding" "$(returns_after "$(returning README.md 'No dead structure')")" '[1]'
assert "a return with no finding counts none" "$(returns_after "$(report "$repo" return)")" '[0]'
assert "a finding an earlier return made counts two" "$(returns_after "$(returning app.py 'No dead structure' 'Rule of three')")" '[2]'
edit app.py 'print(3)'
assert "an accept between returns records no count" "$(returns_after "$(report "$repo" accept)")" '[0]'
assert "that accept lets the change commit" "$(gate 'git commit -am x')" ""

before="$(lines)"
returner="$(fresh_agent)"
assert "a third return of one finding is allowed" "$(record_as "$returner" "$(returning app.py 'Parse at the boundary' 'No dead structure')")" "$(allowed)"
assert "its record counts that finding's third return" "$(stored "$returner" | jq -c '.gate.judgments[0] | [.repo, .verdict, .recorded, .finding_returns_on_commit]')" \
  "$(jq -cn --arg repo "$top" '[$repo, "return", true, 3]')"
assert "the third return logs its verdict and no gate line" \
  "$(new_lines "$before" | jq -sc 'map([.event, .verdict, .repo, .agent])')" "$(jq -cn --arg repo "$top" --arg agent "$returner" '[["verdict", "return", $repo, $agent]]')"
assert "the third return voids the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a fourth return of it counts four" "$(returns_after "$(returning app.py 'No dead structure')")" '[4]'
assert "an accept after the third return records as any accept" "$(record_handback "$(report "$repo" accept)")" "$(allowed)"
assert "that accept lets the commit land" "$(gate 'git commit -am x')" ""

land
edit app.py 'print(4)'
assert "a commit that lands starts the count over" "$(returns_after "$(returning app.py 'No dead structure')")" '[1]'
assert "a second return of it on the new commit counts two" "$(returns_after "$(returning app.py 'No dead structure')")" '[2]'
assert "the same finding at another line counts three" \
  "$(returns_after "$(returning app.py 'No dead structure' | jq -c '.findings[0].where[0].line = 40')")" '[3]'
assert "a finding whose first place is another path is new, though a later place repeats" \
  "$(returns_after "$(returning README.md 'No dead structure' | jq -c --arg path "$top/app.py" '.findings[0].where += [{path: $path, line: 1}]')")" '[1]'

(cd "$repo" && git checkout -q -- app.py)
edit README.md 'other change'
assert "a change replaced by one on other paths starts the count over" "$(returns_after "$(returning app.py 'No dead structure')")" '[1]'

finish
