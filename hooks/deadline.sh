start_in_group() {
  set -m
  "$@" &
  set +m
}

wait_for_groups_within_deadline() {
  local seconds="$1"
  shift
  set -m
  { sleep "$seconds" && kill -- "${@/#/-}"; } >/dev/null 2>&1 </dev/null &
  local watchdog="$!"
  set +m
  local status=0
  wait "$@" 2>/dev/null || status=$?
  kill -- "-$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  return "$status"
}
