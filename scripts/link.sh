#!/usr/bin/env bash
# Symlink this repo's skills into the agents' skill directory, so an edit here is live everywhere.
# Usage: link.sh [name...]   (no names: link every skill and remove links to skills that no longer exist)
set -euo pipefail

repo_skills="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd)"
target="${SKILLS_DIR:-$HOME/.agents/skills}"
mkdir -p "$target"

status=0

link_one() {
  local name="$1" src="$repo_skills/$1" dest="$target/$1"
  if [ ! -f "$src/SKILL.md" ]; then
    echo "error: no skill named $name" >&2
    status=1
  elif [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    :
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "skip $name: $dest exists and is not a link to this repo" >&2
    status=1
  else
    ln -s "$src" "$dest"
    echo "linked $name"
  fi
}

if [ "$#" -gt 0 ]; then
  for name in "$@"; do link_one "$name"; done
  exit "$status"
fi

for dir in "$repo_skills"/*/; do link_one "$(basename "$dir")"; done

for dest in "$target"/*; do
  [ -L "$dest" ] || continue
  case "$(readlink "$dest")" in
    "$repo_skills"/*)
      if [ ! -e "$dest" ]; then
        rm "$dest"
        echo "removed $(basename "$dest")"
      fi
      ;;
  esac
done

exit "$status"
