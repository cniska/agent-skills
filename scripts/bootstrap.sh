#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root"

bun install --frozen-lockfile

mise run validate

echo "Bootstrap complete"
echo "- Git hooks path: $(git config --get core.hooksPath)"
