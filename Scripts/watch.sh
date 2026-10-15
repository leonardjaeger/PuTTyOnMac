#!/bin/bash
# Bauwächter der SSH-App: arbeitet Aufträge aus build/requests/ nacheinander ab.
# Auftrag:  echo <modus> > build/requests/<name>.request
# Ergebnis: build/logs/<name>.log, Status (Exit-Code) in build/logs/status-<name>.txt
# Während ein Auftrag läuft, steht in der Statusdatei "laeuft".
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/requests build/logs

echo "SSH-App Bauwächter läuft in $(pwd | sed "s|^$HOME|~|")"
echo "Beenden mit ctrl-C oder durch Schließen des Fensters."

while true; do
  for req in build/requests/*.request; do
    [ -e "$req" ] || continue
    name=$(basename "$req" .request)
    mode=$(head -c 32 "$req" | tr -d '[:space:]')
    rm -f "$req"
    # Nur einfache Namen, damit Statusdateien nicht außerhalb von build/logs landen
    if [[ ! "$name" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
      echo "$(date '+%H:%M:%S') abgelehnt: ungültiger Auftragsname"
      continue
    fi
    echo "laeuft" > "build/logs/status-$name.txt"
    echo "$(date '+%H:%M:%S') $name: $mode …"
    bash Scripts/build.sh "$mode" > "build/logs/$name.log" 2>&1
    code=$?
    echo "$code" > "build/logs/status-$name.txt"
    echo "$(date '+%H:%M:%S') $name: fertig (Exit $code)"
  done
  sleep 2
done
