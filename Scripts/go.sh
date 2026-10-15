#!/bin/bash
# Für Claude (VM/device_bash): Auftrag stellen und auf das Ergebnis warten.
# Aufruf: bash Scripts/go.sh <modus> <name> [max-sekunden]
# Gibt am Ende das Log aus und endet mit dem Exit-Code des Auftrags
# (124 = Wartezeit abgelaufen, Auftrag läuft weiter; erneut aufrufen mit "warte").
set -u
cd "$(dirname "$0")/.." || exit 1
mode="$1"; name="$2"; max="${3:-160}"
status="build/logs/status-$name.txt"

if [ "$mode" != "warte" ]; then
  [ -e "$status" ] && { echo "Auftragsname '$name' schon benutzt – neuen Namen wählen."; exit 65; }
  mkdir -p build/requests
  echo "$mode" > "build/requests/$name.request"
fi

waited=0
while [ "$waited" -lt "$max" ]; do
  if [ -f "$status" ] && [ "$(cat "$status")" != "laeuft" ]; then
    tail -n 200 "build/logs/$name.log"
    exit "$(cat "$status")"
  fi
  sleep 3; waited=$((waited + 3))
done
if [ ! -f "$status" ]; then
  echo "Auftrag nicht angenommen – läuft der Bauwächter?"
else
  echo "Läuft noch (Wartezeit abgelaufen)."
fi
exit 124
