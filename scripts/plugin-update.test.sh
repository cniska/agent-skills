#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
UPDATE="$HERE/plugin-update.sh"
CHECKOUT="$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")"
HEAD="$(git -C "$CHECKOUT" rev-parse HEAD)"

pass=0
fail=0
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/config/plugins"
cat >"$tmp/bin/claude" <<EOF
#!/usr/bin/env bash
echo "\$* in \$(pwd -P)" >>"$tmp/calls"
EOF
chmod +x "$tmp/bin/claude"

installs() {
  printf '{"version":2,"plugins":{"cniska-skills@cniska":[{"scope":"user","gitCommitSha":"%s"},{"scope":"project","projectPath":"%s","gitCommitSha":"%s"}]}}' \
    "$1" "$CHECKOUT" "$2" >"$tmp/config/plugins/installed_plugins.json"
}
run() { (cd "$HERE" && PATH="$tmp/bin:$PATH" CLAUDE_CONFIG_DIR="$tmp/config" "$UPDATE" >/dev/null 2>&1); echo "$?"; }

installs "$HEAD" "$HEAD"
assert "current installs pass"       "$(run)" 0
assert "user scope updated first"    "$(sed -n 1p "$tmp/calls")" "plugin update cniska-skills@cniska --scope user in $(cd "$HERE" && pwd -P)"
assert "project scope in checkout"   "$(sed -n 2p "$tmp/calls")" "plugin update cniska-skills@cniska --scope project in $(cd "$CHECKOUT" && pwd -P)"

installs 0000000000000000000000000000000000000000 "$HEAD"
assert "a stale user scope fails"    "$(run)" 1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
