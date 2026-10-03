#!/usr/bin/env bash
# Cloud sessions only: install mise and shellcheck, enable the pre-push hook, and load this checkout's skills.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# mise.run and GitHub release downloads are blocked by the cloud proxy; npm and PyPI are not.
command -v mise >/dev/null || npm install -g @jdxcode/mise >/dev/null

shellcheck_version="$(sed -n 's/^shellcheck = "\(.*\)"/\1/p' mise.toml)"
if ! shellcheck --version 2>/dev/null | grep -qx "version: $shellcheck_version"; then
  pip install -q --root-user-action=ignore "shellcheck-py==$shellcheck_version.*"
fi

mise trust -q mise.toml
# Use the PyPI shellcheck on PATH instead of mise's GitHub download.
if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qx 'export MISE_DISABLE_TOOLS=shellcheck' "$CLAUDE_ENV_FILE" 2>/dev/null; then
  echo 'export MISE_DISABLE_TOOLS=shellcheck' >> "$CLAUDE_ENV_FILE"
fi

git config core.hooksPath .githook

SKILLS_DIR="$HOME/.claude/skills" ./scripts/link.sh || echo "warn: some skills were not linked (see above)" >&2
