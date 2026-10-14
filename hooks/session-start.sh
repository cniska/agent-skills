#!/usr/bin/env bash
set -euo pipefail

readonly START_CONTEXT="Start each task with the cniska-skills:task skill, loaded with the Skill tool, and load other skills only as it, or a skill it loads, directs. A commit that changes code waits until cniska-skills:reviewer has accepted the diff as it stands."
readonly RESUME_CONTEXT="This session continues earlier work. When this session coordinates other agents, load the cniska-skills:coordinate skill again and resume its ledger and workers as that skill's Resume section says; otherwise load the cniska-skills:task skill again and re-enter the work's route at the step it stands on."

usage() {
  printf 'session-start.sh: usage: session-start.sh start|resume\n' >&2
  exit 2
}

main() {
  if (($# != 1)); then
    usage
  fi
  case "$1" in
    start) printf '%s\n' "$START_CONTEXT" ;;
    resume) printf '%s\n' "$RESUME_CONTEXT" ;;
    *) usage ;;
  esac
}

main "$@"
