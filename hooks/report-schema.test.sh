#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMAS="$HERE/../mcp/report-schemas.json"

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
source "$HERE/jq-past-shims.test-harness.sh"
link_jq_past_shims "$scratch"
require_jq

schema_jq() {
  jq -r -L "$HERE" --slurpfile schemas "$SCHEMAS" "include \"report-schema\"; $1"
}

schema_facts() {
  jq -nr -L "$HERE" --slurpfile schemas "$SCHEMAS" "include \"report-schema\"; $1"
}

check() {
  schema_jq "tool_violations(\$schemas[0]; \"$1\") | violation_text" <<<"$2"
}

readonly LOCATION='{"path": "/repo/app.py", "line": 3}'
readonly FINDING='{"where": ['"$LOCATION"'], "rule": "Fix the cause", "severity": "major", "why": "It hides the cause.", "instead": "Inject it."}'
judgment() { printf '{"repo": "/repo", "verdict": "%s", "findings": [%s], "conflicts": [], "follow_ups": [], "clean": [{"rule": "No comments", "places": [%s]}]}' "$1" "${2:-}" "$LOCATION"; }
verdict() { printf '{"diffs": ["/tmp/change.diff"], "judgments": [%s]}' "$1"; }
readonly RESEARCH='{"recommendation": "Go ahead.", "evidence": [{"claim": "It exists.", "source": {"kind": "file", "ref": "a.ts:1"}}], "against": "Cost.", "owner_conflicts": [], "unverified": [], "sort": "proposal"}'
readonly SHA=0123456789abcdef0123456789abcdef01234567
readonly TASK_REPORT='{"task": "t", "outcome": "landed", "summary": "Landed.", "landed": {"repo": "/repo", "branch": "main", "sha": "'"$SHA"'", "ci_runs": [{"workflow": "ci", "url": "https://example.com/1", "conclusion": "success"}]}, "choices": [], "owner_questions": [], "follow_ups": ['"$FINDING"'], "open": [], "steps_skipped": [], "plugin_update_due": true}'

assert "the schema file lists the four tools" "$(jq -r '.tools | keys | join(" ")' "$SCHEMAS")" "read_report research task_report verdict"
assert "the schema file uses only keywords the validator checks" "$(schema_facts 'unsupported_keywords($schemas[0]) | join(" ")')" ""
assert "a keyword the validator does not check is caught" \
  "$(schema_facts '$schemas[0] | .["$defs"].text.maxLength = 9 | unsupported_keywords(.) | join(" ")')" "maxLength"
assert "a keyword beside a \$ref is caught" \
  "$(schema_facts '$schemas[0] | .["$defs"].finding.properties.rule.minLength = 2 | unsupported_keywords(.) | join(" ")')" "minLength"
assert "a type list the validator does not check is caught" \
  "$(schema_facts '$schemas[0] | .["$defs"].text.type = ["string", "null"] | unsupported_keywords(.) | join(" ")')" "type"
assert "an additionalProperties other than false is caught" \
  "$(schema_facts '$schemas[0] | .["$defs"].location.additionalProperties = true | unsupported_keywords(.) | join(" ")')" "additionalProperties"
assert "an items list is caught" \
  "$(schema_facts '$schemas[0] | .tools.verdict.inputSchema.properties.diffs.items = [{}] | unsupported_keywords(.) | join(" ")')" "items"
assert "an end anchor before the pattern's end is caught" \
  "$(schema_facts '$schemas[0] | .["$defs"].path.pattern = "^/a$|^/b$" | unsupported_keywords(.) | join(" ")')" "pattern"
assert "a backslash in a pattern is caught" \
  "$(schema_facts '$schemas[0] | .["$defs"].path.pattern = "^/\\d$" | unsupported_keywords(.) | join(" ")')" "pattern"
assert "every \$ref in the schema file resolves to a schema" \
  "$(schema_facts '$schemas[0] as $root | [$root | .. | objects | select(has("$ref")) | resolve($root) | type] | unique | join(" ")')" "object"

assert "a well-formed accept has no violation" "$(check verdict "$(verdict "$(judgment accept)")")" ""
assert "a well-formed return with a finding has no violation" "$(check verdict "$(verdict "$(judgment return "$FINDING")")")" ""
assert "a well-formed research report has no violation" "$(check research "$RESEARCH")" ""
assert "a well-formed task report has no violation" "$(check task_report "$TASK_REPORT")" ""
assert "a well-formed report id has no violation" "$(check read_report '{"id": "a1b2-c3_d4"}')" ""

assert "a value of the wrong type is named" "$(check verdict '{"diffs": "/tmp/x.diff", "judgments": []}')" \
  $'/diffs must be of type array\n/judgments must hold at least 1 item'
assert "the input itself of the wrong type is named" "$(check verdict '[]')" "the input must be of type object"
assert "a value outside its enum is named" "$(check verdict "$(verdict "$(judgment maybe)")")" \
  '/judgments/0/verdict must be one of "accept", "return"'
assert "a missing field is named" "$(check verdict '{"judgments": ['"$(judgment accept)"']}')" "/diffs is required"
assert "an unknown field is named" "$(check read_report '{"id": "a", "agent": "b"}')" "/agent is not a field this tool takes"
assert "an empty list that needs an item is named" "$(check research "$(jq -c '.evidence = []' <<<"$RESEARCH")")" "/evidence must hold at least 1 item"
assert "an empty text is named" "$(check research "$(jq -c '.against = ""' <<<"$RESEARCH")")" "/against must not be empty"
assert "a relative path is named" "$(check verdict "$(verdict "$(judgment accept)" | jq -c '.judgments[0].repo = "repo"')")" \
  "/judgments/0/repo must match the pattern ^/"
assert "a line below 1 is named" "$(check verdict "$(verdict "$(judgment return "$(jq -c '.where[0].line = 0' <<<"$FINDING")")")")" \
  "/judgments/0/findings/0/where/0/line must be at least 1"
assert "a fractional line is named as the wrong type" "$(check verdict "$(verdict "$(judgment return "$(jq -c '.where[0].line = 1.5' <<<"$FINDING")")")")" \
  "/judgments/0/findings/0/where/0/line must be of type integer"
assert "a short sha is named" "$(check task_report "$(jq -c '.landed.sha = "0123abc"' <<<"$TASK_REPORT")")" \
  '/landed/sha must match the pattern ^[0-9a-f]{40}$'
assert "a sha with a trailing newline is named" "$(check task_report "$(jq -c '.landed.sha += "\n"' <<<"$TASK_REPORT")")" \
  '/landed/sha must match the pattern ^[0-9a-f]{40}$'
assert "an id with a trailing newline is named" "$(check read_report '{"id": "a1\n"}')" \
  '/id must match the pattern ^[A-Za-z0-9_-]{1,128}$'
assert "a nested finding's missing field is named through every \$ref" \
  "$(check task_report "$(jq -c 'del(.follow_ups[0].instead)' <<<"$TASK_REPORT")")" "/follow_ups/0/instead is required"
assert "every violation is named, not only the first" \
  "$(check verdict "$(verdict "$(judgment return "$(jq -c '.severity = "high" | del(.why)' <<<"$FINDING")")")" | wc -l | tr -d ' ')" 2

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
