def quoted_string: "\"(?:[^\"\\\\]|\\\\[\\\\\"nrt])*\"";
def number_token: "^-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$";
def root_line: "^(?<key>" + quoted_string + "|[A-Za-z_][A-Za-z0-9_.]*)(?<rest>.*)$";
def array_header: "^\\[[0-9]+[,|\\t]?\\](?:\\{[^}]*\\})?:(?<inline> .+)?$";

def decoded_key: if startswith("\"") then fromjson else . end;

def primitive:
  if startswith("\"") then
    if test("^" + quoted_string + "$") then {string: fromjson} else null end
  elif test("^(?:true|false|null)$") or test(number_token) then {other: .}
  else {string: .}
  end;

def root_entry:
  (capture(root_line) // null) as $line
  | if $line == null then null
    elif ($line.rest | test("^:$")) then {key: ($line.key | decoded_key), opens: true}
    elif ($line.rest | startswith(": ")) then
      ($line.rest | ltrimstr(": ") | primitive) as $value
      | if $value == null then null else {key: ($line.key | decoded_key), opens: false, value: $value} end
    elif ($line.rest | test(array_header)) then
      {key: ($line.key | decoded_key), opens: (($line.rest | capture(array_header).inline) == null)}
    else null
    end;

def skipped: test("^ *(?:#.*)?$");

def shared_value:
  reduce (split("\n")[] | select(skipped | not)) as $line (
    {decodes: true, open: false, keys: {}, shared: null};
    if .decodes | not then .
    elif $line | startswith(" ") then
      if .open then . else .decodes = false end
    else
      ($line | root_entry) as $entry
      | if $entry == null or (.keys | has($entry.key)) then .decodes = false
        else
          .keys[$entry.key] = true
          | .open = $entry.opens
          | if $entry.key == "shared" then .shared = $entry.value.string else . end
        end
    end
  )
  | select(.decodes)
  | .shared
  | strings;

shared_value
