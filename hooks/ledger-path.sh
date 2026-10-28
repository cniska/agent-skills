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

ledger_data_home() {
  local data="${XDG_DATA_HOME:-}"
  case "$data" in
    /*) printf '%s' "$data" ;;
    *) printf '%s/.local/share' "$(ledger_home)" ;;
  esac
}

ledger_project_root() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}"
  local common
  if common="$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    case "$common" in
      */.git) dirname -- "$common" ;;
      *) printf '%s\n' "$common" ;;
    esac
    return
  fi
  if ! (cd -- "$dir" 2>/dev/null && pwd -P); then
    printf '%s\n' "$dir"
  fi
}

ledger_path() {
  if [ -n "${AGENT_LEDGER:-}" ]; then
    printf '%s\n' "$AGENT_LEDGER"
    return
  fi
  local root
  root="$(ledger_project_root)"
  printf '%s/agent-skills/%s/ledger.toon\n' "$(ledger_data_home)" "${root//\//-}"
}

shared_file() {
  local target
  target="$(jq -Rsr -f "$(dirname -- "${BASH_SOURCE[0]}")/ledger-shared.jq" <"$1")" || return 1
  case "$target" in
    "") ;;
    /*) printf '%s\n' "$target" ;;
    *) printf '%s/%s\n' "$(dirname -- "$1")" "$target" ;;
  esac
}
