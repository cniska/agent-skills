link_jq_past_shims() {
  local bin="$1/bin" dir found=""
  while IFS= read -r -d : dir; do
    [ -n "$dir" ] && [ -f "$dir/jq" ] && [ -x "$dir/jq" ] || continue
    [ "$(basename "$(realpath "$dir/jq")")" = mise ] && continue
    found="$dir/jq"
    break
  done <<<"$PATH:"
  if [ -z "$found" ]; then
    printf 'jq is not on PATH outside mise shims\n' >&2
    exit 1
  fi
  mkdir -p "$bin"
  ln -s "$found" "$bin/jq"
  export PATH="$bin:$PATH"
}

require_jq() {
  if ! jq -n 1 >/dev/null; then
    printf 'jq does not run: jq -n 1 failed\n' >&2
    exit 1
  fi
}
