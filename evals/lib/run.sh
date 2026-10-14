#!/usr/bin/env bash
set -euo pipefail

readonly USAGE="usage: run.sh [--skill <name>] [--against <git-ref>|none] [claude plugin eval options]"

skill=""
against=""
eval_args=()
root=""
work=""

die() {
  printf 'run.sh: %s\n' "$1" >&2
  exit "${2:-1}"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --skill)
        (($# >= 2)) || die "--skill needs a name" 2
        skill="$2"
        shift 2
        ;;
      --against)
        (($# >= 2)) || die "--against needs a git ref or none" 2
        against="$2"
        shift 2
        ;;
      -h | --help)
        printf '%s\n' "$USAGE"
        exit 0
        ;;
      *)
        eval_args+=("$1")
        shift
        ;;
    esac
  done
}

use_this_trees_cases() {
  local tree="$1"
  rm -rf "$tree/evals" "$tree/.claude-plugin/marketplace.json"
  rsync -a --exclude results "$root/evals/" "$tree/evals/"
}

run_side() {
  local tree="$1" result="$2"
  local tag=()
  [ -z "$skill" ] || tag=(--tag "$skill")
  if ! (cd "$tree" && claude plugin eval . "${tag[@]+"${tag[@]}"}" --scaffold --allow-tools Bash Edit Write \
    --trust-plugin --no-publish --ablation none --json "$result" "${eval_args[@]+"${eval_args[@]}"}" >"$result.log" 2>&1); then
    printf 'run.sh: %s scored below threshold or failed; reading its result\n' "$(basename "$tree")" >&2
  fi
  [ -s "$result" ] || die "no result from $(basename "$tree"); see $result.log"
}

main() {
  parse_args "$@"
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  bun --version >/dev/null 2>&1 || die "bun is required; run mise install"
  claude --version >/dev/null 2>&1 || die "claude is required to run evals"
  [ "$against" != none ] || [ -n "$skill" ] || die "--against none needs --skill" 2
  [ -z "$skill" ] || compgen -G "$root/skills/*/$skill/SKILL.md" >/dev/null || die "no skill $skill under skills/workflow/ or skills/expertise/" 2

  local cases
  cases="$(bun "$root/evals/lib/list-cases.ts" "$skill" | tr '\n' ' ')"
  [ -n "$cases" ] || die "no case is tagged ${skill:-at all}"

  local out
  work="$(mktemp -d "${TMPDIR:-/tmp}/eval.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
  out="$root/evals/results/$(date -u +%Y-%m-%dT%H-%M-%SZ)${skill:+-$skill}"
  mkdir -p "$out"

  rsync -a --exclude .git --exclude node_modules --exclude 'evals/results' "$root/" "$work/head/"
  use_this_trees_cases "$work/head"
  if [ "$against" = none ]; then
    rsync -a "$work/head/" "$work/base/"
    rm -rf "$work/base/skills/"*/"$skill"
  elif [ -n "$against" ]; then
    mkdir -p "$work/base"
    git -C "$root" archive "$against" | tar -x -C "$work/base"
    use_this_trees_cases "$work/base"
  fi

  local pids=() pid failed=0
  run_side "$work/head" "$out/head.json" &
  pids+=($!)
  if [ -n "$against" ]; then
    run_side "$work/base" "$out/base.json" &
    pids+=($!)
  fi
  for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
  ((failed == 0)) || exit 1

  if [ -n "$against" ]; then
    printf '%s on %s(base: %s, head: this tree)\n' "${skill:-all skills}" "$cases" "$against"
    bun "$root/evals/lib/summary.ts" "$out/base.json" "$out/head.json"
  else
    bun "$root/evals/lib/summary.ts" "$out/head.json"
  fi
  printf 'results: %s\n' "$out"
}

main "$@"
