readonly RUN_LIMIT_SECONDS="${CNISKA_RUN_LIMIT_SECONDS:-1800}"

runs_dir() {
  printf '%s/runs/%s\n' "$CLAUDE_PLUGIN_DATA" "$(data_key "$1")"
}

record_run() {
  local agent="$1" task="$2" output="$3" dir
  dir="$(runs_dir "$agent")"
  mkdir -p "$dir" && printf '%s\t%s\t%s\n' "$task" "$output" "$(date +%s)" >"$dir/$(data_key "$task")"
}

lsof_command() {
  command -v lsof 2>/dev/null && return
  [ ! -x /usr/sbin/lsof ] || printf '/usr/sbin/lsof\n'
}

can_see_open_files() {
  [ -n "$(lsof_command)" ] || [ -d /proc/self/fd ]
}

file_open() {
  local file="$1" lsof fd
  lsof="$(lsof_command)"
  if [ -n "$lsof" ]; then
    "$lsof" -t -- "$file" >/dev/null 2>&1
    return
  fi
  for fd in /proc/[0-9]*/fd/*; do
    [ "$(readlink "$fd" 2>/dev/null)" != "$file" ] || return 0
  done
  return 1
}

drop_finished_runs() {
  local input="$1" dir running entry task started now
  dir="$(runs_dir "$(reporter_id "$input")")"
  [ -d "$dir" ] || return 0
  running="$(jq -r '.background_tasks[]? | select(.status == "running") | .id' <<<"$input")"
  now="$(date +%s)"
  for entry in "$dir"/*; do
    [ -f "$entry" ] || continue
    IFS=$'\t' read -r task _ started <"$entry"
    if ! grep -qxF -- "$task" <<<"$running" || [ "$((now - ${started:-0}))" -ge "$RUN_LIMIT_SECONDS" ]; then
      rm -f "$entry" || return 1
    fi
  done
}

held_runs() {
  local input="$1" dir entry task output
  dir="$(runs_dir "$(reporter_id "$input")")"
  [ -d "$dir" ] || return 0
  if ! jq -e 'has("background_tasks")' <<<"$input" >/dev/null; then
    printf '%s: no background command is held: the stop names no background_tasks\n' "${0##*/}" >&2
    return 0
  fi
  if ! can_see_open_files; then
    printf '%s: no background command is held: neither lsof nor /proc can tell when one ends\n' "${0##*/}" >&2
    return 0
  fi
  for entry in "$dir"/*; do
    [ -f "$entry" ] || continue
    IFS=$'\t' read -r task output _ <"$entry"
    printf '%s\t%s\n' "$task" "$output"
  done
}

ended_runs() {
  local task output
  while IFS=$'\t' read -r task output; do
    [ -n "$task" ] || continue
    file_open "$output" || printf '%s\t%s\n' "$task" "$output"
  done <<<"$1"
}

runs_left() {
  local runs="$1" ran="$2" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    grep -qxF -- "$line" <<<"$ran" || printf '%s\n' "$line"
  done <<<"$runs"
}

run_tasks() {
  cut -f 1 <<<"$1" | sed '/^$/d' | paste -sd ' ' -
}

drop_runs() {
  local dir task
  dir="$(runs_dir "$1")"
  while IFS=$'\t' read -r task _; do
    [ -z "$task" ] || rm -f "$dir/$(data_key "$task")"
  done <<<"$2"
}
