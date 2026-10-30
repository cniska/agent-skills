#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="$HERE/report-server.sh"

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
source "$HERE/../hooks/jq-past-shims.test-harness.sh"
link_jq_past_shims "$scratch"
require_jq

readonly DATA="$scratch/data"
mkdir -p "$DATA/reports"

serve() {
  printf '%s\n' "$@" | CLAUDE_PLUGIN_DATA="$DATA" "$SERVER"
}

call() {
  jq -cn --arg name "$1" --argjson arguments "$2" '{jsonrpc: "2.0", id: 7, method: "tools/call", params: {name: $name, arguments: $arguments}}'
}

initialize() {
  jq -cn --arg version "$1" '{jsonrpc: "2.0", id: 1, method: "initialize", params: {protocolVersion: $version, capabilities: {}, clientInfo: {name: "test", version: "1"}}}'
}

readonly LIST='{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}'
tools() { serve "$LIST" | jq -c '.result.tools'; }

assert "a supported protocol version is answered with itself" \
  "$(serve "$(initialize 2025-06-18)" | jq -c '.result.protocolVersion')" '"2025-06-18"'
assert "an unsupported protocol version is answered with the latest one the server speaks" \
  "$(serve "$(initialize 2099-01-01)" | jq -c '.result.protocolVersion')" '"2025-11-25"'
assert "initialize names the tools capability and the server" \
  "$(serve "$(initialize 2025-11-25)" | jq -c '[.id, .result.capabilities, .result.serverInfo.name]')" '[1,{"tools":{}},"report"]'
assert "a notification gets no reply" \
  "$(serve '{"jsonrpc": "2.0", "method": "notifications/initialized"}' | wc -l | tr -d ' ')" 0
assert "ping is answered with an empty result" "$(serve '{"jsonrpc": "2.0", "id": 3, "method": "ping"}')" '{"jsonrpc":"2.0","id":3,"result":{}}'

assert "tools/list lists the four tools" "$(tools | jq -r 'map(.name) | join(" ")')" "verdict research task_report read_report"
assert "every listed tool loads upfront" "$(tools | jq -c 'map(._meta["anthropic/alwaysLoad"]) | unique')" "[true]"
assert "every listed tool has a description" "$(tools | jq -c 'map(.description | type) | unique')" '["string"]'
assert "no listed schema keeps a \$ref" "$(tools | jq -c '[.. | objects | select(has("$ref"))] | length')" 0
assert "a \$ref is inlined with the schema it names" \
  "$(tools | jq -c '.[] | select(.name == "verdict") | .inputSchema.properties.judgments.items.properties.findings.items.properties.where.items.required')" '["path"]'
assert "a description beside a \$ref is kept where the field is used" \
  "$(tools | jq -r '.[] | select(.name == "verdict") | .inputSchema.properties.judgments.items.properties.repo.description')" \
  "The repository the change is in; for a change in a worktree, that worktree's path."
assert "the listed schema is the schema file's, with every \$ref resolved" \
  "$(tools | jq -c '.[] | select(.name == "research") | .inputSchema.properties.evidence.items.properties.source.properties.kind')" \
  '{"enum":["session","file","url"]}'

assert "a report tool's call is acknowledged" \
  "$(serve "$(call verdict '{"diffs": [], "judgments": []}')" | jq -c '[.id, .result.isError, (.result.content[0].text | startswith("Report received."))]')" '[7,false,true]'
assert "an unknown tool is a JSON-RPC error" \
  "$(serve "$(call nothing '{}')" | jq -c '.error')" '{"code":-32602,"message":"No tool is named \"nothing\"."}'
assert "an unknown method is a JSON-RPC error" \
  "$(serve '{"jsonrpc": "2.0", "id": 4, "method": "resources/list"}' | jq -c '[.id, .error.code]')" '[4,-32601]'
assert "a line that is not JSON is a parse error" "$(serve 'nope' | jq -c '[.id, .error.code]')" '[null,-32700]'
assert "a request that is not an object is an invalid request" "$(serve '[1]' | jq -c '[.id, .error.code]')" '[null,-32600]'
assert "a request whose params is not an object is an invalid request with its id" \
  "$(serve '{"jsonrpc": "2.0", "id": 9, "method": "initialize", "params": "x"}' | jq -c '[.id, .error.code]')" '[9,-32600]'
assert "the server answers the line after a bad one" "$(serve 'nope' '{"jsonrpc": "2.0", "id": 5, "method": "ping"}' | jq -sc 'map(.id)')" '[null,5]'

readonly RECORD='{"tool": "verdict", "agent_type": "cniska-skills:reviewer", "agent_id": "a1b2", "session_id": "s1", "payload": {"diffs": []}, "gate": {"recorded": true}}'
printf '%s\n' "$RECORD" >"$DATA/reports/a1b2.json"
printf 'secret\n' >"$DATA/outside.json"
printf '{"broken"\n' >"$DATA/reports/broken.json"

assert "a stored report is returned as structured content" \
  "$(serve "$(call read_report '{"id": "a1b2"}')" | jq -c '.result.structuredContent')" "$(jq -c . <<<"$RECORD")"
assert "a stored report is returned as JSON text too" \
  "$(serve "$(call read_report '{"id": "a1b2"}')" | jq -c '.result.content[0].text | fromjson')" "$(jq -c . <<<"$RECORD")"
assert "a stored report is not an error" "$(serve "$(call read_report '{"id": "a1b2"}')" | jq -c '.result.isError // false')" false
assert "a missing report is a tool error naming the id" \
  "$(serve "$(call read_report '{"id": "zz9"}')" | jq -c '[.result.isError, .result.content[0].text]')" \
  '[true,"No report is stored for zz9: the agent made no report call, or its call was refused."]'
assert "an id outside the allowed characters is refused before any file is read" \
  "$(serve "$(call read_report '{"id": "../outside"}')" | jq -c '[.result.isError, .result.content[0].text]')" \
  '[true,"/id must match the pattern ^[A-Za-z0-9_-]{1,128}$"]'
assert "a call with no id is refused by the schema" \
  "$(serve "$(call read_report '{}')" | jq -c '[.result.isError, .result.content[0].text]')" '[true,"/id is required"]'
assert "a stored report that is not JSON is a tool error" \
  "$(serve "$(call read_report '{"id": "broken"}')" | jq -c '[.result.isError, (.result.content[0].text | startswith("The report stored for broken is not valid JSON"))]')" '[true,true]'
assert "with no plugin data directory, reading is a tool error" \
  "$(printf '%s\n' "$(call read_report '{"id": "a1b2"}')" | env -u CLAUDE_PLUGIN_DATA "$SERVER" | jq -c '[.result.isError, .result.content[0].text]')" \
  '[true,"No report can be read: CLAUDE_PLUGIN_DATA is not set for the report server."]'

mkdir -p "$scratch/faulty/mcp"
cp "$SERVER" "$scratch/faulty/mcp/"
ln -s "$HERE/../hooks" "$scratch/faulty/hooks"
faulty() { printf '%s\n' "$@" | "$scratch/faulty/mcp/report-server.sh" 2>/dev/null; }
assert "a server fault is answered with an internal error carrying the request's id" \
  "$(faulty '{"jsonrpc": "2.0", "id": 6, "method": "ping"}' | jq -c '[.id, .error.code]')" '[6,-32603]'
assert "a server fault on a notification gets no reply" \
  "$(faulty '{"jsonrpc": "2.0", "method": "notifications/initialized"}' | wc -l | tr -d ' ')" 0

assert "the plugin config starts this server" \
  "$(jq -r '.mcpServers.report.command' "$HERE/../.mcp.json")" '${CLAUDE_PLUGIN_ROOT}/mcp/report-server.sh'
assert "the server is executable" "$([ -x "$SERVER" ] && echo yes)" yes

serve_as_claude_code_launches() {
  local assignments
  assignments=()
  local assignment
  while IFS= read -r assignment; do
    assignments+=("$assignment")
  done < <(jq -r --arg root "$HERE/.." --arg data "$DATA" \
    '{CLAUDE_PLUGIN_ROOT: $root, CLAUDE_PLUGIN_DATA: $data} + (.mcpServers.report.env // {}) | to_entries[] | "\(.key)=\(.value)"' \
    "$HERE/../.mcp.json")
  printf '%s\n' "$@" | env -u CLAUDE_PLUGIN_DATA "${assignments[@]}" "$SERVER"
}
assert "the server Claude Code launches from the plugin config reads the reports the hooks store" \
  "$(serve_as_claude_code_launches "$(call read_report '{"id": "a1b2"}')" | jq -c '.result.structuredContent.agent_id')" '"a1b2"'

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
