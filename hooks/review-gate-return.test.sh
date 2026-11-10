#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

readonly DESIGNER=cniska-skills:designer

top="$(cd "$repo" && git rev-parse --show-toplevel)"
new_lines() { tail -n +"$(($1 + 1))" "$log"; }
lines() { wc -l <"$log" | tr -d ' '; }
counts() { stored "$1" | jq -c '.gate.returns | [.any_severity, .critical_or_major]'; }
returning() {
  local severity="$2"
  report "$repo" return ".findings = [$(finding "$top/$1" 'Size everything to the need' "$severity")]"
}
next_round() {
  hand_back "$1" "${3:-}" >/dev/null
  record_as "$1" "$2" "${3:-}" >/dev/null
}

edit app.py 'print(2)'
first="$(fresh_agent)"
assert "a first return off the schema keeps its reviewer running" \
  "$(record_as "$first" "$(returning app.py major | jq -c 'del(.conflicts)')" | jq -r .hookSpecificOutput.permissionDecision)" deny
record_as "$first" "$(returning app.py major)" >/dev/null
assert "the fixed return counts once in both numbers, its refused call not at all" "$(counts "$first")" '[1,1]'
next_round "$first" "$(returning app.py minor)"
assert "a minor-only return counts only under any severity" "$(counts "$first")" '[2,1]'
next_round "$first" "$(returning README.md critical)"
assert "a critical return on another path counts in both numbers" "$(counts "$first")" '[3,2]'
next_round "$first" "$(report "$repo" return | jq -c --argjson conflict "$(finding "$top/app.py" 'Size everything to the need' major)" '.conflicts = [$conflict]')"
assert "a return with only conflicts counts in neither" "$(counts "$first")" '[3,2]'
next_round "$first" "$(report "$repo" return '.reason = "no_diff"')"
assert "a return that judged nothing counts in neither" "$(counts "$first")" '[3,2]'

land
edit app.py 'print(3)'
hand_back "$first" >/dev/null
assert "a return past the third is allowed like any other" "$(record_as "$first" "$(returning app.py major)")" "$(allowed)"
assert "a moved HEAD changes nothing: the count is the reviewer's" "$(counts "$first")" '[4,3]'
next_round "$first" "$(report "$repo" accept)"
assert "a recorded accept ends the review, so its count starts again at zero" "$(counts "$first")" '[0,0]'
assert "that accept lets the change commit" "$(gate 'git commit -am x')" ""

edit app.py 'print(31)'
counted=()
for step in return accept return return return; do
  if [ "$step" = accept ]; then
    next_round "$first" "$(report "$repo" accept)"
  else
    next_round "$first" "$(returning app.py major)"
  fi
  counted+=("$(counts "$first")")
done
assert "the next review counts only its returns since the last accept" "${counted[*]}" '[1,1] [0,0] [1,1] [2,2] [3,3]'
hand_back "$first" >/dev/null
record_as "$first" "$(returning app.py major | jq -c 'del(.conflicts)')" >/dev/null
assert "an accept in the round of a refused return" "$(record_as "$first" "$(report "$repo" accept)" | jq -r .hookSpecificOutput.permissionDecision)" allow
assert "is not recorded, so it keeps the count" "$(counts "$first")" '[3,3]'
(cd "$repo" && git checkout -q -- app.py)

second="$(fresh_agent)"
edit app.py 'print(4)'
record_as "$second" "$(returning app.py major)" >/dev/null
assert "a new reviewer on the same change starts at zero" "$(counts "$second")" '[1,1]'

other="$scratch/other"
mkdir -p "$other"
(cd "$other" && git init -q -b main && printf 'z = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'z = 2\n' >>lib.py)
other_top="$(cd "$other" && git rev-parse --show-toplevel)"
two="$(fresh_agent)"
record_as "$two" "$(returning app.py major)
$(report "$other" return ".findings = [$(finding "$other_top/lib.py" 'Size everything to the need' major)]")" >/dev/null
assert "one report across two repositories counts as one return" "$(counts "$two")" '[1,1]'

designer="$(fresh_agent)"
record_as "$designer" "$(returning app.py major)" "$DESIGNER" >/dev/null
assert "a designer's return counts like a reviewer's" "$(counts "$designer")" '[1,1]'
next_round "$designer" "$(returning app.py minor)" "$DESIGNER"
assert "a designer's minor-only return counts only under any severity" "$(counts "$designer")" '[2,1]'
for reason in verify_gap run_blocked run_short; do
  next_round "$designer" "$(returning app.py major | jq -c --arg reason "$reason" '.reason = $reason')" "$DESIGNER"
  assert "a designer's $reason return judges no screen, so it counts in neither" "$(counts "$designer")" '[2,1]'
done

stubborn="$(fresh_agent)"
unknown="$(returning app.py major | jq -c '.findings[0].rule = "Nothing of the kind"')"
record_as "$stubborn" "$unknown" >/dev/null
record_as "$stubborn" "$unknown" >/dev/null
assert "a report stored as not recorded still carries the numbers, uncounted" \
  "$(stored "$stubborn" | jq -c '[.gate.recorded, .gate.code, .gate.returns.any_severity]')" '[false,"rule_unknown",0]'

(cd "$repo" && git checkout -q -- app.py)
edit app.py 'print(5)'
assert "an accept before the return records as any accept" "$(record_handback "$(report "$repo" accept)")" "$(allowed)"
before="$(lines)"
returner="$(fresh_agent)"
assert "a reviewer's return is allowed" "$(record_as "$returner" "$(returning app.py major)")" "$(allowed)"
assert "its record carries repo, verdict and recorded, and no per-commit count" \
  "$(stored "$returner" | jq -c '.gate.judgments[0]')" \
  "$(jq -cn --arg repo "$top" '{repo: $repo, verdict: "return", recorded: true, code: null, fix: null}')"
assert "the return logs its verdict and no gate line" \
  "$(new_lines "$before" | jq -sc 'map([.event, .verdict, .repo, .agent])')" "$(jq -cn --arg repo "$top" --arg agent "$returner" '[["verdict", "return", $repo, $agent]]')"
assert "the return voids the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "an accept after it records as any accept" "$(record_handback "$(report "$repo" accept)")" "$(allowed)"
assert "that accept lets the commit land" "$(gate 'git commit -am x')" ""

finish
