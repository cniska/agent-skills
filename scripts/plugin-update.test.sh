#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT
BUN="$(cd "$HERE" && bun -e 'process.stdout.write(process.execPath)')" || exit 1
while IFS= read -r key; do unset "$key"; done < <(compgen -e | grep '^GIT_')
export HOME="$tmp/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$tmp"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
mkdir -p "$HOME" "$tmp/bin" "$tmp/config/plugins" "$tmp/checkout/scripts"

CHECKOUT="$tmp/checkout"
WORKTREE="$tmp/worktree"
cp "$HERE/plugin-update.sh" "$CHECKOUT/scripts/plugin-update.sh"
ln -s "$HERE/plugin-check.ts" "$CHECKOUT/scripts/plugin-check.ts"
git -C "$CHECKOUT" init -q -b main
git -C "$CHECKOUT" add -A
git -C "$CHECKOUT" commit -q -m checkout
git -C "$CHECKOUT" worktree add -q -b task "$WORKTREE"
git -C "$WORKTREE" commit -q --allow-empty -m task
HEAD="$(git -C "$CHECKOUT" rev-parse HEAD)"
UPDATE="$WORKTREE/scripts/plugin-update.sh"

cat >"$tmp/bin/claude" <<EOF
#!/usr/bin/env bash
echo "\$* in \$(pwd -P)" >>"$tmp/calls"
EOF
chmod +x "$tmp/bin/claude"
ln -s "$BUN" "$tmp/bin/bun"

installs() {
  printf '{"version":2,"plugins":{"cniska-skills@cniska":[{"scope":"user","gitCommitSha":"%s"},{"scope":"project","projectPath":"%s","gitCommitSha":"%s"}]}}' \
    "$1" "$CHECKOUT" "$2" >"$tmp/config/plugins/installed_plugins.json"
}
run() { (cd "$WORKTREE" && PATH="$tmp/bin:$PATH" CLAUDE_CONFIG_DIR="$tmp/config" "$UPDATE" >/dev/null 2>&1); echo "$?"; }

installs "$HEAD" "$HEAD"
assert "current installs pass"       "$(run)" 0
assert "user scope updated first"    "$(sed -n 1p "$tmp/calls")" "plugin update cniska-skills@cniska --scope user in $(cd "$WORKTREE" && pwd -P)"
assert "project scope in checkout"   "$(sed -n 2p "$tmp/calls")" "plugin update cniska-skills@cniska --scope project in $(cd "$CHECKOUT" && pwd -P)"

installs 0000000000000000000000000000000000000000 "$HEAD"
assert "a stale user scope fails"    "$(run)" 1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
