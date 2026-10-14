#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/ledger-path.sh"

main() {
  local ledger
  ledger="$(ledger_path)"
  if [ -f "$ledger" ]; then
    cat -- "$ledger"
  fi
}

main "$@"
