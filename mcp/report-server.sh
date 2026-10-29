#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../hooks/report-store.sh"
readonly SCHEMAS="$HERE/report-schemas.json"
readonly SCHEMA_LIB="$HERE/../hooks"
readonly SUPPORTED_VERSIONS='["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]'
readonly SERVER_INFO='{"name": "report", "version": "1"}'
readonly RECEIVED_TEXT="Report received. Hand back now with a one-line message; your caller reads the report itself."

readonly RPC='
  def reply($id; $result): {jsonrpc: "2.0", id: $id, result: $result};
  def failure($id; $code; $message): {jsonrpc: "2.0", id: $id, error: {code: $code, message: $message}};
  def tool_text($id; $text; $error): reply($id; {content: [{type: "text", text: $text}], isError: $error});'

readonly ROUTE='include "report-schema";'"$RPC"'
  $schemas[0] as $root
  | ($versions | fromjson) as $supported
  | (try ($line | fromjson | {message: .}) catch {}) as $parsed
  | if ($parsed | has("message") | not) then failure(null; -32700; "The line is not JSON.")
    elif ($parsed.message | type) != "object" or ($parsed.message.method | type) != "string"
      or ($parsed.message | has("params") and (.params | type) != "object") then
      failure($parsed.message.id? // null; -32600; "A request is a JSON object with a method, and its params, when given, an object.")
    else
      $parsed.message
      | select(has("id"))
      | .id as $id
      | if .method == "initialize" then
          reply($id; {
            protocolVersion: (.params.protocolVersion as $asked | if any($supported[]; . == $asked) then $asked else $supported[0] end),
            capabilities: {tools: {}},
            serverInfo: ($info | fromjson)
          })
        elif .method == "ping" then reply($id; {})
        elif .method == "tools/list" then
          reply($id; {tools: [$root.tools | to_entries[] | {
            name: .key,
            description: .value.description,
            inputSchema: (.value.inputSchema | inline_refs($root)),
            _meta: {"anthropic/alwaysLoad": true}
          }]})
        elif .method == "tools/call" then
          .params.name as $tool
          | .params.arguments as $arguments
          | if ($root.tools | has($tool | tostring) | not) then failure($id; -32602; "No tool is named \($tool | tojson).")
            elif $tool != "read_report" then tool_text($id; $received; false)
            else
              [$arguments | tool_violations($root; "read_report") | violation_text] as $violations
              | if ($violations | length) > 0 then tool_text($id; $violations | join("\n"); true)
                else {read: $arguments.id, id: $id} end
            end
        else failure($id; -32601; "No method is named \(.method | tojson).")
        end
    end'

readonly STORED="$RPC"'
  reply($id; {content: [{type: "text", text: ($record[0] | tojson)}], structuredContent: $record[0]})'

readonly NOT_STORED="$RPC"' tool_text($id; $text; true)'

readonly SERVER_FAULT="$RPC"'
  try (fromjson | objects | select(has("id")) | failure(.id; -32603; "The report server failed on this request: \($fault)")) catch empty'

not_stored() {
  jq -cn --argjson id "$1" --arg text "$2" "$NOT_STORED"
}

read_report() {
  local report_id="$1" rpc_id="$2"
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    not_stored "$rpc_id" "No report can be read: CLAUDE_PLUGIN_DATA is not set for the report server."
    return
  fi
  local file
  file="$(report_file "$report_id")"
  if [ ! -f "$file" ]; then
    not_stored "$rpc_id" "No report is stored for $report_id: the agent made no report call, or its call was refused."
    return
  fi
  jq -cn --argjson id "$rpc_id" --slurpfile record "$file" "$STORED" 2>/dev/null ||
    not_stored "$rpc_id" "The report stored for $report_id is not valid JSON: $file"
}

answer() {
  local routed
  routed="$(jq -cn -L "$SCHEMA_LIB" --slurpfile schemas "$SCHEMAS" \
    --arg line "$1" --arg versions "$SUPPORTED_VERSIONS" --arg info "$SERVER_INFO" --arg received "$RECEIVED_TEXT" \
    "$ROUTE")" || return 1
  [ -n "$routed" ] || return 0
  if [ "$(jq -r 'has("read")' <<<"$routed")" = true ]; then
    read_report "$(jq -r '.read' <<<"$routed")" "$(jq -c '.id' <<<"$routed")"
    return
  fi
  printf '%s\n' "$routed"
}

main() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    answer "$line" && continue
    printf 'report-server: no answer for a line: jq failed\n' >&2
    jq -cR --arg fault "jq failed" "$SERVER_FAULT" <<<"$line"
  done
}

main
