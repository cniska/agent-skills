#!/usr/bin/env bash
# Behavioral evals: run a skill headless via `claude -p`, grade the transcript,
# gate on pass-rate regression. Dev-only, makes real API calls. See README.md.
# Scenario files (sourced) provide skill/task/det_*/sem_* etc:
# shellcheck disable=SC1090,SC2154

EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"
BASELINE_FILE="$EVALS_DIR/baseline-results.json"
SKILLS_DIR="$(cd "$EVALS_DIR/.." && pwd)/skills"

opt_baseline=0 opt_update=0 opt_yes=0 opt_skill="" opt_k="" opt_ablate=""
for a in "$@"; do
  case "$a" in
    --baseline) opt_baseline=1 ;;
    --update-baseline) opt_update=1 ;;
    --yes | -y) opt_yes=1 ;;
    --skill=*) opt_skill="${a#--skill=}" ;;
    --k=*) opt_k="${a#--k=}" ;;
    --ablate=*) opt_ablate="${a#--ablate=}" ;;
  esac
done

# A rate gap this wide or wider counts as a real difference between two arms;
# anything narrower is two runs flipping at k=5 and proves nothing either way.
ABLATE_THRESHOLD=40

# The single point of API access. skills=0 disables all skills (the baseline arm).
# $3, when set, is a file whose text is appended to the system prompt — how the
# ablation arms deliver skill text, since the installed skill is disabled.
# Tests override this with a stub, so the whole harness runs offline.
claude_run() { # prompt skills [system-prompt-file]
  local extra=()
  [ "$2" = 0 ] && extra=(--disable-slash-commands)
  [ -n "${3:-}" ] && extra+=(--append-system-prompt-file "$3")
  claude -p "$1" --output-format json "${extra[@]}" | jq -r '.result // ""'
}

# The skill with one addressed rule line removed. The address must resolve to
# exactly one line — rules.sh enforces that; here a miss is fatal rather than a
# silently unmodified arm, which would read as "the rule does nothing".
trim_skill() { # skill-file address -> trimmed text on stdout
  local hits
  hits="$(grep -Fc -- "$2" "$1")"
  [ "$hits" -eq 1 ] || {
    echo "ablate: address matches $hits lines in $1, need exactly 1: $2" >&2
    return 1
  }
  grep -Fv -- "$2" "$1"
}

# Blinded per-assertion judge -> "pass"/"fail". A pass whose evidence isn't a
# verbatim substring of the output is rejected (guards hallucinated evidence).
judge() { # transcript assertion
  local raw verdict quote
  raw="$(claude_run "Grade the output against ONE assertion. Judge only this assertion.

ASSERTION: $2

Reply with ONLY: {\"verdict\":\"pass\"|\"fail\",\"evidence_quote\":\"<verbatim span, or empty>\"}

OUTPUT FOLLOWS:
$1" 0)"
  verdict="$(printf '%s' "$raw" | jq -r '.verdict // "fail"' 2>/dev/null || echo fail)"
  quote="$(printf '%s' "$raw" | jq -r '.evidence_quote // ""' 2>/dev/null || echo "")"
  if [ "$verdict" = pass ] && { [ -z "$quote" ] || [[ "$1" == *"$quote"* ]]; }; then
    echo pass
  else
    echo fail
  fi
}

det_check() { # transcript regex expect(present|absent)
  local found=0
  printf '%s' "$1" | grep -Eq -- "$2" && found=1
  if { [ "$3" = present ] && [ "$found" = 1 ]; } || { [ "$3" = absent ] && [ "$found" = 0 ]; }; then
    echo pass
  else
    echo fail
  fi
}

# Runs one arm k times and sets det_rate[]/sem_rate[] (percent, parallel to the
# scenario's det_id[]/sem_id[]). Reads the scenario arrays from the global scope.
run_arm() { # prompt skills k [system-prompt-file]
  local prompt="$1" skills="$2" k="$3" sys="${4:-}" t i transcript
  local dc=() sc=()
  for i in "${!det_id[@]}"; do dc[i]=0; done
  for i in "${!sem_id[@]}"; do sc[i]=0; done
  for ((t = 0; t < k; t++)); do
    transcript="$(claude_run "$prompt" "$skills" "$sys")"
    for i in "${!det_id[@]}"; do
      [ "$(det_check "$transcript" "${det_re[i]}" "${det_expect[i]}")" = pass ] && dc[i]=$((dc[i] + 1))
    done
    for i in "${!sem_id[@]}"; do
      [ "$(judge "$transcript" "${sem_assertion[i]}")" = "${sem_expect[i]}" ] && sc[i]=$((sc[i] + 1))
    done
  done
  det_rate=() sem_rate=()
  for i in "${!det_id[@]}"; do det_rate[i]=$((dc[i] * 100 / k)); done
  for i in "${!sem_id[@]}"; do sem_rate[i]=$((sc[i] * 100 / k)); done
}

rate_of() { # id -> percent from the last run_arm
  local i
  for i in "${!det_id[@]}"; do [ "${det_id[i]}" = "$1" ] && { echo "${det_rate[i]}"; return; }; done
  for i in "${!sem_id[@]}"; do [ "${sem_id[i]}" = "$1" ] && { echo "${sem_rate[i]}"; return; }; done
  echo 0
}

# Three arms differing only in the skill text: full, full minus one rule, none.
# The installed skill is disabled in all three, so the arms cannot differ by how
# the skill was invoked — only by what it said.
run_ablation() { # scenario-file address k -> prints the comparison
  local f="$1" addr="$2" kk="$3" skill_file trimmed prompt i id full trim none verdict
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  [ -f "$skill_file" ] || {
    echo "ablate: no such skill: $skill" >&2
    return 1
  }
  trimmed="$(mktemp)"
  trim_skill "$skill_file" "$addr" > "$trimmed" || {
    rm -f "$trimmed"
    return 1
  }

  prompt="$task

$(cat "$(dirname "$f")/$fixture")"

  local -a full_det full_sem trim_det trim_sem none_det none_sem
  run_arm "$prompt" 0 "$kk" "$skill_file"
  full_det=(${det_rate[@]+"${det_rate[@]}"}) full_sem=(${sem_rate[@]+"${sem_rate[@]}"})
  run_arm "$prompt" 0 "$kk" "$trimmed"
  trim_det=(${det_rate[@]+"${det_rate[@]}"}) trim_sem=(${sem_rate[@]+"${sem_rate[@]}"})
  run_arm "$prompt" 0 "$kk" ""
  none_det=(${det_rate[@]+"${det_rate[@]}"}) none_sem=(${sem_rate[@]+"${sem_rate[@]}"})
  rm -f "$trimmed"

  printf '\n  %-20s %6s %8s %6s   %s\n' assertion full trimmed none verdict
  for i in "${!det_id[@]}"; do
    id="${det_id[i]}" full="${full_det[i]}" trim="${trim_det[i]}" none="${none_det[i]}"
    verdict="$(ablate_verdict "$full" "$trim")"
    printf '  %-20s %5d%% %7d%% %5d%%   %s\n' "$id" "$full" "$trim" "$none" "$verdict"
  done
  for i in "${!sem_id[@]}"; do
    id="${sem_id[i]}" full="${full_sem[i]}" trim="${trim_sem[i]}" none="${none_sem[i]}"
    verdict="$(ablate_verdict "$full" "$trim")"
    printf '  %-20s %5d%% %7d%% %5d%%   %s\n' "$id" "$full" "$trim" "$none" "$verdict"
  done
}

ablate_verdict() { # full trimmed -> proven | harm | no effect
  local d=$(($1 - $2))
  if [ "$d" -ge "$ABLATE_THRESHOLD" ]; then
    echo "proven — removing it costs ${d} points"
  elif [ "$d" -le "-$ABLATE_THRESHOLD" ]; then
    echo "HARM — removing it gains $((-d)) points"
  else
    echo "no effect at this threshold"
  fi
}

main() {
  set -uo pipefail
  local scns=() f
  while IFS= read -r f; do
    [ -n "$opt_skill" ] && [ "$(basename "$(dirname "$f")")" != "$opt_skill" ] && continue
    scns+=("$f")
  done < <(find "$EVALS_DIR" -mindepth 2 -name '*.sh' | sort)
  [ "${#scns[@]}" -eq 0 ] && {
    echo "no scenarios found" >&2
    exit 1
  }

  local arms=1
  [ "$opt_baseline" = 1 ] && arms=2
  [ -n "$opt_ablate" ] && arms=3
  local est=0 sk sn
  for f in "${scns[@]}"; do
    read -r sk sn < <(
      set +u
      unset sem_id
      k=""
      source "$f"
      echo "${opt_k:-${k:-3}} ${#sem_id[@]}"
    )
    est=$((est + sk * (1 + sn) * arms))
  done

  if [ "$opt_yes" != 1 ]; then
    [ -t 0 ] || {
      echo "Refusing to run non-interactively without --yes — this makes real API calls." >&2
      exit 1
    }
    local ans
    read -r -p "~$est real \`claude -p\` calls across ${#scns[@]} scenario(s). Continue? [y/N] " ans
    case "$ans" in
      y | Y | yes | Yes) ;;
      *)
        echo "aborted."
        exit 0
        ;;
    esac
  fi

  local ver regressed=0 update_lines=()
  ver="$(claude --version 2>/dev/null | head -1)"

  for f in "${scns[@]}"; do
    unset det_id det_re det_expect sem_id sem_assertion sem_expect baseline_must_fail
    source "$f"
    local kk="${opt_k:-${k:-3}}" name key fx
    name="$(basename "$f" .sh)"
    key="$skill/$name"
    fx="$(cat "$(dirname "$f")/$fixture")"
    echo
    echo "=== $key (k=$kk, $ver) ==="

    # Ablation is a self-contained three-arm experiment: it answers whether one
    # rule earns its place, and never touches the baseline file, whose numbers
    # come from the installed skill rather than injected text.
    if [ -n "$opt_ablate" ]; then
      echo "  ablating: $opt_ablate"
      run_ablation "$f" "$opt_ablate" "$kk" || exit 1
      continue
    fi

    run_arm "$invoke

$task

$fx" 1 "$kk"

    local all_id=() all_pct=() i id pct base tag reg
    for i in "${!det_id[@]}"; do
      all_id+=("${det_id[i]}")
      all_pct+=("${det_rate[i]}")
    done
    for i in "${!sem_id[@]}"; do
      all_id+=("${sem_id[i]}")
      all_pct+=("${sem_rate[i]}")
    done
    for i in "${!all_id[@]}"; do
      id="${all_id[i]}"
      pct="${all_pct[i]}"
      base="$(jq -r --arg k "$key" --arg id "$id" '.[$k][$id] // empty' "$BASELINE_FILE" 2>/dev/null || true)"
      tag="" reg=""
      if [ -n "$base" ]; then
        tag=" (was ${base}%)"
        [ "$pct" -lt "$base" ] && {
          reg="  REGRESSION"
          regressed=1
        }
      fi
      printf '  %3d%%  %s%s%s\n' "$pct" "$id" "$tag" "$reg"
      update_lines+=("$key"$'\t'"$id"$'\t'"$pct")
    done

    if [ "$opt_baseline" = 1 ]; then
      run_arm "$task

$fx" 0 "$kk"
      echo "  no-skill baseline (must fail these to discriminate):"
      local mf r w
      for mf in ${baseline_must_fail[@]+"${baseline_must_fail[@]}"}; do
        r="$(rate_of "$mf")"
        w=""
        [ "$r" -gt 0 ] && w="  WEAK"
        printf '     %s: %d%%%s\n' "$mf" "$r" "$w"
      done
    fi
  done

  if [ "$opt_update" = 1 ]; then
    printf '%s\n' "${update_lines[@]}" |
      jq -Rn '[inputs | split("\t") | {k: .[0], id: .[1], pct: (.[2] | tonumber)}]
              | reduce .[] as $r ({}; .[$r.k][$r.id] = $r.pct)' > "$BASELINE_FILE"
    echo
    echo "wrote $BASELINE_FILE"
  fi

  echo
  if [ "$regressed" = 1 ]; then
    echo "RESULT: regression"
    exit 1
  fi
  echo "RESULT: ok"
}

# Run only when executed, not when sourced (so tests can drive the functions).
if ! (return 0 2> /dev/null); then main "$@"; fi
