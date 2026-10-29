def schema_keywords:
  ["$ref", "type", "enum", "required", "properties", "additionalProperties", "items", "minItems", "minLength", "pattern", "minimum", "description"];

def resolve($root):
  if type == "object" and has("$ref") then
    . as $node
    | $root | getpath($node["$ref"] | ltrimstr("#/") | split("/")) | resolve($root)
  else . end;

def json_type:
  if type == "number" and . == floor then "integer" else type end;

def type_matches($want):
  json_type as $have | $want == $have or ($want == "number" and $have == "integer");

def ecma_end_anchor:
  if endswith("$") then .[:-1] + "\\z" else . end;

def violations($root; $schema; $path):
  . as $value
  | ($schema | resolve($root)) as $s
  | if ($s | has("type")) and ($value | type_matches($s.type) | not) then
      {path: $path, rule: "type", want: $s.type}
    else
      (if ($s | has("enum")) and (any($s.enum[]; . == $value) | not) then {path: $path, rule: "enum", want: $s.enum} else empty end),
      (if ($value | type) == "string" then
        (if ($s | has("minLength")) and ($value | length) < $s.minLength then {path: $path, rule: "minLength", want: $s.minLength} else empty end),
        (if ($s | has("pattern")) and ($value | test($s.pattern | ecma_end_anchor) | not) then {path: $path, rule: "pattern", want: $s.pattern} else empty end)
      else empty end),
      (if ($value | type) == "number" and ($s | has("minimum")) and $value < $s.minimum then {path: $path, rule: "minimum", want: $s.minimum} else empty end),
      (if ($value | type) == "object" then
        (($s.required // [])[] | select(. as $key | $value | has($key) | not) | {path: ($path + [.]), rule: "required", want: true}),
        (if $s.additionalProperties == false then
          $value | keys[] | select(. as $key | $s.properties // {} | has($key) | not) | {path: ($path + [.]), rule: "additionalProperties", want: false}
        else empty end),
        (($s.properties // {}) | to_entries[] | select(.key as $key | $value | has($key)) | . as $field
          | $value[$field.key] | violations($root; $field.value; $path + [$field.key]))
      else empty end),
      (if ($value | type) == "array" then
        (if ($s | has("minItems")) and ($value | length) < $s.minItems then {path: $path, rule: "minItems", want: $s.minItems} else empty end),
        (if $s | has("items") then range(0; $value | length) as $i | $value[$i] | violations($root; $s.items; $path + [$i]) else empty end)
      else empty end)
    end;

def tool_violations($root; $tool):
  violations($root; $root.tools[$tool].inputSchema; []);

def pointer:
  if length == 0 then "the input" else "/" + (map(tostring) | join("/")) end;

def violation_text:
  (.path | pointer) + " "
  + if .rule == "type" then "must be of type " + .want
    elif .rule == "enum" then "must be one of " + (.want | map(tojson) | join(", "))
    elif .rule == "required" then "is required"
    elif .rule == "additionalProperties" then "is not a field this tool takes"
    elif .rule == "minItems" then "must hold at least \(.want) item" + (if .want == 1 then "" else "s" end)
    elif .rule == "minLength" then (if .want == 1 then "must not be empty" else "must hold at least \(.want) characters" end)
    elif .rule == "pattern" then "must match the pattern \(.want)"
    elif .rule == "minimum" then "must be at least \(.want)"
    else error("no text for the rule \(.rule)") end;

def unsupported_keywords($root):
  def nodes:
    ., (.properties // {} | .[] | nodes), (.items // empty | objects | nodes);
  def unsupported:
    (keys - schema_keywords)[],
    (select(has("$ref")) | (keys - ["$ref", "description"])[]),
    (select(has("type") and (.type | type) != "string") | "type"),
    (select(has("additionalProperties") and .additionalProperties != false) | "additionalProperties"),
    (select(has("items") and (.items | type) != "object") | "items"),
    (select(has("pattern") and (.pattern | contains("\\") or (.[:-1] | contains("$")))) | "pattern");
  [$root["$defs"][], ($root.tools[] | .inputSchema) | nodes | unsupported] | unique;

def inline_refs($root):
  if type == "object" and has("$ref") then
    (resolve($root) | inline_refs($root)) + (if has("description") then {description} else {} end)
  elif type == "object" then map_values(inline_refs($root))
  elif type == "array" then map(inline_refs($root))
  else . end;
