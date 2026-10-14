#!/usr/bin/env bash
set -euo pipefail

readonly START_CONTEXT="Start each task with the cniska-skills:task skill, loaded with the Skill tool, and load other skills only as it, or a skill it loads, directs. A commit that changes code waits until cniska-skills:reviewer has accepted the diff as it stands."
readonly RESUME_CONTEXT="This session continues earlier work. Load the cniska-skills:task skill again and take its Resume route before the next step, or cniska-skills:coordinate when this session coordinates other agents."

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
