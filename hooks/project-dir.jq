def quoted_string: "\"(?:[^\"\\\\]|\\\\[\\\\\"nrt])*\"";
def table_header: "^  projects\\[[0-9]+\\]\\{id,name,repo,dir\\}:$";
def row_prefix: "    ";

def cells:
  (capture("^(?<cell>" + quoted_string + "|[^\",]*)(?:,(?<rest>.*))?$") // null) as $match
  | if $match == null then null
    else
      ($match.cell | if startswith("\"") then fromjson else . end),
      (if $match.rest == null then empty else ($match.rest | cells) end)
    end;

def rows($lines; $from):
  $lines[$from:]
  | (map(startswith(row_prefix) and (ltrimstr(row_prefix) | startswith(" ") | not)) | index(false) // length) as $end
  | .[:$end][]
  | ltrimstr(row_prefix);

def project_dir($id):
  split("\n") as $lines
  | first(range($lines | length) | select($lines[.] | test(table_header))) as $at
  | first(rows($lines; $at + 1) | [cells] | select(length == 4 and all(strings) and .[0] == $id) | .[3]);

project_dir($id)
