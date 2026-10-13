#!/usr/bin/env bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

command -v mise >/dev/null || npm install -g @jdxcode/mise >/dev/null

shellcheck_version="$(sed -n 's/^shellcheck = "\(.*\)"/\1/p' mise.toml)"
if ! shellcheck --version 2>/dev/null | grep -qx "version: $shellcheck_version"; then
  pip install -q --root-user-action=ignore "shellcheck-py==$shellcheck_version.*"
fi

mise trust -q mise.toml
if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qx 'export MISE_DISABLE_TOOLS=shellcheck' "$CLAUDE_ENV_FILE" 2>/dev/null; then
  echo 'export MISE_DISABLE_TOOLS=shellcheck' >> "$CLAUDE_ENV_FILE"
fi

bun install --frozen-lockfile >&2
