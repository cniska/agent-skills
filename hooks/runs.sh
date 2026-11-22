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

can_judge_runs() {
  local input="$1"
  [ -d "$(runs_dir "$(reporter_id "$input")")" ] || return 1
  if ! jq -e 'has("background_tasks")' <<<"$input" >/dev/null; then
    printf '%s: no background command is held: the stop names no background_tasks\n' "${0##*/}" >&2
    return 1
  fi
  if ! can_see_open_files; then
    printf '%s: no background command is held: neither lsof nor /proc can tell when one ends\n' "${0##*/}" >&2
    return 1
  fi
}

recorded_runs() {
  local input="$1" dir running entry task output started now state
  dir="$(runs_dir "$(reporter_id "$input")")"
  running="$(jq -r '.background_tasks[]? | select(.status == "running") | .id' <<<"$input")"
  now="$(date +%s)"
  for entry in "$dir"/*; do
    [ -f "$entry" ] || continue
    IFS=$'\t' read -r task output started <"$entry"
    if ! grep -qxF -- "$task" <<<"$running"; then
      state=ended
    elif [ "$((now - ${started:-0}))" -ge "$RUN_LIMIT_SECONDS" ]; then
      state=lapsed
    else
      state=running
    fi
    printf '%s\t%s\t%s\n' "$task" "$output" "$state"
  done
}

runs_in_state() {
  local task output state
  while IFS=$'\t' read -r task output state; do
    [ "$state" != "$2" ] || printf '%s\t%s\t%s\n' "$task" "$output" "$state"
  done <<<"$1"
}

ended_runs() {
  local task output state
  while IFS=$'\t' read -r task output state; do
    [ -n "$task" ] || continue
    file_open "$output" || printf '%s\t%s\tended\n' "$task" "$output"
  done <<<"$1"
}

runs_left() {
  local runs="$1" ran="$2" task output state
  while IFS=$'\t' read -r task output state; do
    [ -n "$task" ] || continue
    cut -f 1 <<<"$ran" | grep -qxF -- "$task" || printf '%s\t%s\t%s\n' "$task" "$output" "$state"
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
