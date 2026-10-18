#!/bin/bash
# Für Claude (VM/device_bash): Auftrag stellen und auf das Ergebnis warten.
# Aufruf: bash Scripts/go.sh <modus> <name> [max-sekunden]   ·   bash Scripts/go.sh warte <name> [max-sekunden]
# Gibt am Ende das Log aus und endet mit dem Exit-Code des Auftrags (124 = Wartezeit abgelaufen, läuft weiter).
# Die Ablage ist die des Bauwächters (~/Library/Caches/TunnelTerminal-Build/waechter), in der VM unter mnt/TunnelTerminal-Build.
set -u
mode="$1"; name="$2"; max="${3:-160}"
queue="${TUNNELTERMINAL_WAECHTER:-$HOME/mnt/TunnelTerminal-Build/waechter}"
status="$queue/logs/status-$name.txt"

if [ "$mode" != "warte" ]; then
  [[ "$name" =~ ^[A-Za-z0-9_-]{1,64}$ ]] || { echo "Auftragsname nur aus A–Z, a–z, 0–9, _ und - (höchstens 64)."; exit 64; }
  [ -e "$status" ] && { echo "Auftragsname '$name' schon benutzt – neuen Namen wählen."; exit 65; }
  mkdir -p "$queue/requests"
  # Atomar: der Wächter sieht den Auftrag erst vollständig (über die VM-Freigabe kann er sonst leer ankommen)
  echo "$mode" > "$queue/requests/.$name.tmp" && mv "$queue/requests/.$name.tmp" "$queue/requests/$name.request"
fi

waited=0
while [ "$waited" -lt "$max" ]; do
  if [ -f "$status" ] && [ "$(cat "$status")" != "laeuft" ]; then
    tail -n 200 "$queue/logs/$name.log"
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
