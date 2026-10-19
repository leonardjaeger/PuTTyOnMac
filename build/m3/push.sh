#!/bin/bash
# Push nach der Abnahme (Bauwächter, Modus skript): „push los“ in build/m3/schritt.txt. Keine Rückfragen am Terminal.
set -u
cd "$(dirname "$0")/../.." || exit 1
export GIT_TERMINAL_PROMPT=0
if [ "${1:-}" = "pruef" ]; then
  /usr/bin/time -p git ls-remote --heads origin 2>&1 | tail -5; echo "ls-remote exit ${PIPESTATUS[0]}"
  curl -sS -o /dev/null -w 'github.com HTTPS %{http_code} in %{time_total}s\n' --max-time 20 https://github.com/ 2>&1
  exit 0
fi
[ "${1:-}" = "los" ] || { echo "Aufruf: push.sh los|pruef"; exit 64; }
git status -sb | head -1
git push origin main 2>&1 && git push origin --tags 2>&1
echo "push exit $?"
git status -sb | head -1
