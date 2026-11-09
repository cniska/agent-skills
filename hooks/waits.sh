readonly WAIT_HOLD_SECONDS="${CNISKA_WAIT_HOLD_SECONDS:-240}"
readonly WAIT_LIMIT_SECONDS="${CNISKA_WAIT_LIMIT_SECONDS:-1800}"
readonly WAIT_POLL_SECONDS=2
readonly ENDED_SUFFIX=.ended

waits_dir() {
  printf '%s/waits/%s\n' "$CLAUDE_PLUGIN_DATA" "$(data_key "$1")"
}

wait_on() {
  local waiter="$1" agent="$2" dir
  dir="$(waits_dir "$waiter")"
  mkdir -p "$dir" && printf '%s\t%s\n' "$agent" "$(date +%s)" >"$dir/$(data_key "$agent")"
}

drop_wait() {
  local entry
  entry="$(waits_dir "$1")/$(data_key "$2")"
  rm -f "$entry" "$entry$ENDED_SUFFIX"
}

end_waits_on() {
  local entry
  for entry in "$CLAUDE_PLUGIN_DATA"/waits/*/"$(data_key "$1")"; do
    [ -f "$entry" ] || continue
    mv "$entry" "$entry$ENDED_SUFFIX" || return 1
  done
}

release_waits() {
  local id="$1"
  end_waits_on "$id" && rm -rf "$(waits_dir "$id")"
}

drop_overdue_waits() {
  local dir entry sent now
  dir="$(waits_dir "$1")"
  [ -d "$dir" ] || return 0
  now="$(date +%s)"
  for entry in "$dir"/*; do
    [ -f "$entry" ] && [ "${entry%"$ENDED_SUFFIX"}" = "$entry" ] || continue
    sent="$(cut -f 2 "$entry")"
    [ "$((now - ${sent:-0}))" -lt "$WAIT_LIMIT_SECONDS" ] || rm -f "$entry" || return 1
  done
}

waits_in_state() {
  local dir
  dir="$(waits_dir "$1")"
  [ -d "$dir" ] || return 0
  if [ "$2" = ended ]; then
    find "$dir" -type f -name "*$ENDED_SUFFIX" -exec cat {} +
  else
    find "$dir" -type f ! -name "*$ENDED_SUFFIX" -exec cat {} +
  fi | cut -f 1 | sort -u | paste -sd ' ' -
}

has_waits() {
  local dir
  dir="$(waits_dir "$1")"
  [ -d "$dir" ] && [ -n "$(ls -A "$dir")" ]
}

hold_wait() {
  local id="$1" waited=0
  while [ -n "$(waits_in_state "$id" waiting)" ] && [ "$waited" -lt "$WAIT_HOLD_SECONDS" ]; do
    sleep "$WAIT_POLL_SECONDS"
    waited=$((waited + WAIT_POLL_SECONDS))
  done
}

clear_ended_waits() {
  find "$(waits_dir "$1")" -type f -name "*$ENDED_SUFFIX" -delete 2>/dev/null || true
}
