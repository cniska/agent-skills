#!/usr/bin/env bash
# Rule inventory: every rule-shaped line in every skill, and whether a scenario
# assertion claims to prove it. Offline — no API calls. See README.md.
# Scenario files are sourced for det_rule/sem_rule:
# shellcheck disable=SC1090,SC2154

EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(cd "$EVALS_DIR/.." && pwd)/skills"

# A rule-shaped line is body prose or a list item: everything that instructs.
# Frontmatter, headings and fenced blocks carry no rule of their own.
rule_lines() { # skill-file -> "lineno<TAB>text" per rule-shaped line
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { fm = 0; next }
    fm { next }
    /^```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*$/ { next }
    /^#/ { next }
    { printf "%d\t%s\n", NR, $0 }
  ' "$1"
}

# Addresses are substrings so a scenario survives rewording elsewhere in the
# line. Ambiguity is a hard error: an address matching two lines proves neither.
match_count() { # skill-file address -> count of rule-shaped lines containing it
  rule_lines "$1" | cut -f2- | grep -Fc -- "$2"
}

# An address must resolve to exactly one rule line. Zero means the rule was
# reworded or removed and the assertion now proves nothing; several means the
# assertion cannot say which rule it proves. Both are errors, not warnings.
check_address() { # skill-file skill-name address -> "ok" | "error" (+ stderr)
  local hit
  hit="$(match_count "$1" "$3")"
  if [ "$hit" -eq 1 ]; then
    echo ok
  else
    printf 'ERROR: %s: address matches %s rule lines, need exactly 1: %s\n' "$2" "$hit" "$3" >&2
    echo error
  fi
}

# Every det_rule/sem_rule entry across all scenarios, as "skill<TAB>address".
claimed_addresses() {
  local f
  while IFS= read -r f; do
    (
      set +u
      unset det_rule sem_rule skill
      source "$f" > /dev/null 2>&1
      for a in ${det_rule[@]+"${det_rule[@]}"} ${sem_rule[@]+"${sem_rule[@]}"}; do
        [ -n "$a" ] && printf '%s\t%s\n' "$skill" "$a"
      done
    )
  done < <(find "$EVALS_DIR" -mindepth 2 -name '*.sh' ! -name '*.test.sh' | sort)
}

main() {
  set -uo pipefail
  local only="" verbose=0 a
  for a in "$@"; do
    case "$a" in
      --skill=*)
        only="${a#--skill=}"
        verbose=1
        ;;
      --verbose) verbose=1 ;;
    esac
  done

  local claims total=0 claimed=0 bad=0
  claims="$(claimed_addresses)"

  local f name lines n c hit addr
  for f in "$SKILLS_DIR"/*/SKILL.md; do
    name="$(basename "$(dirname "$f")")"
    [ -n "$only" ] && [ "$name" != "$only" ] && continue
    lines="$(rule_lines "$f")"
    n="$(printf '%s' "$lines" | grep -c . || true)"
    local addrs
    addrs="$(printf '%s\n' "$claims" | awk -F'\t' -v s="$name" '$1 == s {print $2}')"

    while IFS= read -r addr; do
      [ -z "$addr" ] && continue
      [ "$(check_address "$f" "$name" "$addr")" = error ] && bad=$((bad + 1))
    done <<< "$addrs"

    # Count distinct rule lines, not addresses — two assertions may prove one rule.
    c=0
    while IFS=$'\t' read -r ln text; do
      [ -z "$ln" ] && continue
      hit=untested
      while IFS= read -r addr; do
        [ -n "$addr" ] && [[ "$text" == *"$addr"* ]] && hit=claimed
      done <<< "$addrs"
      [ "$hit" = claimed ] && c=$((c + 1))
      [ "$verbose" = 1 ] && printf '  %-9s %s:%s %.90s\n' "$hit" "$name" "$ln" "$text"
    done <<< "$lines"

    total=$((total + n))
    claimed=$((claimed + c))
    printf '%-20s %3d rules  %3d claimed  %3d untested\n' "$name" "$n" "$c" "$((n - c))"
  done

  echo
  printf 'TOTAL %d rules, %d claimed by an assertion, %d untested\n' "$total" "$claimed" "$((total - claimed))"
  [ "$bad" -gt 0 ] && {
    echo "FAIL: $bad unresolvable address(es)" >&2
    exit 1
  }
  return 0
}

# Run only when executed, not when sourced (so tests can drive the functions).
if ! (return 0 2> /dev/null); then main "$@"; fi
