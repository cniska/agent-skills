#!/usr/bin/env bash
set -euo pipefail

plugin="cniska-skills@cniska"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checkout="$(dirname "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)")"

claude plugin update "$plugin" --scope user
(cd "$checkout" && claude plugin update "$plugin" --scope project)
bun "$here/plugin-check.ts" "$checkout"
