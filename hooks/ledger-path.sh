ledger_home() {
  local home="${HOME:-}"
  if [ -z "${home//[[:space:]]/}" ]; then
    home="$(
      unset HOME
      printf '%s' ~
    )"
  fi
  printf '%s' "$home"
}

ledger_path() {
  if [ -n "${AGENT_LEDGER:-}" ]; then
    printf '%s\n' "$AGENT_LEDGER"
    return
  fi
  local state="${XDG_STATE_HOME:-}"
  case "$state" in
    /*) ;;
    *) state="$(ledger_home)/.local/state" ;;
  esac
  printf '%s/agent-skills/ledger.md\n' "$state"
}
