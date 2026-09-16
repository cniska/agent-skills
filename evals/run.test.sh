#!/usr/bin/env bash
# Unit tests for run.sh — pure bash + jq, no API calls (claude_run is stubbed).
# Run: ./run.test.sh   (exit 0 = all pass, 1 = failures)
# Fixtures set vars and override claude_run for the sourced run.sh to consume:
# shellcheck disable=SC2034,SC2154,SC2329
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./run.sh
source "$HERE/run.sh" # sourced -> main() does not run

pass=0
fail=0
assert() { # desc got want
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

# det_check: present / absent over a transcript
assert "det present hit" "$(det_check 'x **Critical** y' '\*\*(Critical|Fix)\*\*' present)" pass
assert "det present miss" "$(det_check 'no label here' '\*\*(Critical|Fix)\*\*' present)" fail
assert "det absent hit" "$(det_check 'clean output' 'FORBIDDEN' absent)" pass
assert "det absent miss" "$(det_check 'has FORBIDDEN' 'FORBIDDEN' absent)" fail

# judge: a pass is trusted only if its evidence is a verbatim substring
T='subtotal exactly 100 returns 100 instead of 90'
claude_run() { printf '%s' '{"verdict":"pass","evidence_quote":"exactly 100"}'; }
assert "judge pass, verbatim evidence" "$(judge "$T" a)" pass
claude_run() { printf '%s' '{"verdict":"pass","evidence_quote":"not in transcript"}'; }
assert "judge pass, fabricated evidence -> fail" "$(judge "$T" a)" fail
claude_run() { printf '%s' '{"verdict":"fail","evidence_quote":""}'; }
assert "judge fail verdict" "$(judge "$T" a)" fail
claude_run() { printf '%s' 'not json at all'; }
assert "judge unparseable -> fail" "$(judge "$T" a)" fail

# run_arm: the stub routes judge calls (prompt contains ASSERTION:) vs skill runs.
skill=demo invoke=/demo task=t k=1
det_id=(has-label) det_re=('\*\*Critical\*\*') det_expect=(present)
sem_id=(sem1) sem_assertion=(a) sem_expect=(pass)

claude_run() { case "$1" in *ASSERTION:*) printf '{"verdict":"pass","evidence_quote":"bug"}' ;; *) printf '**Critical** a bug' ;; esac; }
run_arm p 1 3
assert "run_arm det 100%" "${det_rate[0]}" 100
assert "run_arm sem 100%" "${sem_rate[0]}" 100
assert "rate_of by id" "$(rate_of sem1)" 100
assert "rate_of unknown -> 0" "$(rate_of nope)" 0

claude_run() { case "$1" in *ASSERTION:*) printf '{"verdict":"pass","evidence_quote":"bug"}' ;; *) printf 'a bug, but no label' ;; esac; }
run_arm p 1 3
assert "run_arm det 0% when label absent" "${det_rate[0]}" 0

# trim_skill: removes exactly the addressed line, and refuses to guess.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'keep one\nremove this rule\nkeep two\n' > "$TMP/SKILL.md"
assert "trim drops the addressed line" \
  "$(trim_skill "$TMP/SKILL.md" 'remove this rule' | grep -c 'remove this rule')" 0
assert "trim keeps the rest" "$(trim_skill "$TMP/SKILL.md" 'remove this rule' | grep -c keep)" 2
trim_skill "$TMP/SKILL.md" 'no such line' > /dev/null 2>&1
assert "trim refuses an address matching nothing" "$?" 1
printf 'dup rule\ndup rule\n' > "$TMP/DUP.md"
trim_skill "$TMP/DUP.md" 'dup rule' > /dev/null 2>&1
assert "trim refuses an ambiguous address" "$?" 1

# ablate_verdict: only a gap at or past the threshold is a finding.
assert "verdict proven" "$(ablate_verdict 100 40 | cut -d' ' -f1)" proven
assert "verdict harm" "$(ablate_verdict 40 100 | cut -d' ' -f1)" HARM
assert "verdict no effect below threshold" "$(ablate_verdict 100 61 | cut -d' ' -f1-2)" "no effect"
assert "verdict at exactly the threshold counts" "$(ablate_verdict 100 60 | cut -d' ' -f1)" proven

# claude_run passes the skill text as a system-prompt file, and disables the
# installed skill in every ablation arm so the arms differ only by that text.
claude_run() { printf 'skills=%s sys=%s' "$2" "${3:-none}"; }
assert "arm carries its system prompt" "$(claude_run p 0 /tmp/x.md)" "skills=0 sys=/tmp/x.md"
assert "arm with no text" "$(claude_run p 0 '')" "skills=0 sys=none"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
