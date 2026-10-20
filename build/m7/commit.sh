#!/bin/bash
# Commit, Tag und Push nach der Abnahme (Bauwächter, Modus skript): „commit los“ bzw. „commit push“ in build/m7/schritt.txt.
# Nachricht aus build/m7/commit.txt (nicht im Repo). Keine Rückfragen am Terminal.
set -u
cd "$(dirname "$0")/../.." || exit 1
export GIT_TERMINAL_PROMPT=0
case "${1:-}" in
  los)
    [ -s build/m7/commit.txt ] || { echo "build/m7/commit.txt fehlt"; exit 64; }
    git rev-parse -q --verify refs/tags/m7 >/dev/null && { echo "Tag m7 gibt es schon"; exit 65; }
    git add -A && git commit -q -F build/m7/commit.txt && git tag m7 || exit 1
    git log --oneline -1; git tag --points-at HEAD; git status --short | head -5; echo "commit exit 0"
    ;;
  push)
    git status -sb | head -1
    git push origin main 2>&1 && git push origin m7 2>&1
    echo "push exit $?"
    git status -sb | head -1
    ;;
  *) echo "Aufruf: commit.sh los|push"; exit 64 ;;
esac
