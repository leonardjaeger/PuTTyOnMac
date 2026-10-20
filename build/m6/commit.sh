#!/bin/bash
# Commit und Tag nach der Abnahme (Bauwächter, Modus skript): „commit los“ in build/m6/schritt.txt.
# Nachricht aus build/m6/commit.txt (nicht im Repo). Kein Push (dafür build/m3/push.sh).
set -u
cd "$(dirname "$0")/../.." || exit 1
[ "${1:-}" = "los" ] || { echo "Aufruf: commit.sh los"; exit 64; }
[ -s build/m6/commit.txt ] || { echo "build/m6/commit.txt fehlt"; exit 64; }
git rev-parse -q --verify refs/tags/m6 >/dev/null && { echo "Tag m6 gibt es schon"; exit 65; }
git add -A && git commit -q -F build/m6/commit.txt && git tag m6 || exit 1
git log --oneline -1; git tag --points-at HEAD; git status --short | head -5; echo "commit exit 0"
