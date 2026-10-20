#!/bin/bash
# Bauwächter von TunnelTerminal: arbeitet Aufträge nacheinander ab.
# Ablage außerhalb von iCloud (M0, Vorschlag 10): ~/Library/Caches/TunnelTerminal-Build/waechter
#   Auftrag:  echo <modus> > requests/<name>.request
#   Ergebnis: logs/<name>.log, Exit-Code in logs/status-<name>.txt („laeuft“, solange er arbeitet)
# Jedes Log beginnt mit den Prüfsummen der Skripte (und im Modus „skript“ deren Inhalt);
# jeder Auftrag hat ein Zeitlimit; Statusdateien werden atomar geschrieben (tmp + mv).
set -u -m   # -m: jeder Auftrag bekommt eine eigene Prozessgruppe, damit das Zeitlimit ihn ganz beenden kann
cd "$(dirname "$0")/.." || exit 1
queue="$HOME/Library/Caches/TunnelTerminal-Build/waechter"
mkdir -p "$queue/requests" "$queue/logs"
chmod 700 "$queue" "$queue/requests" "$queue/logs"

limit_for() {
  case "$1" in
    test) echo 1800 ;;
    build) echo 1200 ;;
    skript) echo 900 ;;
    kern) echo 600 ;;
    *) echo 120 ;;
  esac
}

write_status() {
  printf '%s\n' "$2" > "$queue/logs/.status-$1.tmp" && mv -f "$queue/logs/.status-$1.tmp" "$queue/logs/status-$1.txt"
}

echo "TunnelTerminal Bauwächter läuft in $(pwd | sed "s|^$HOME|~|")"
echo "Beenden mit ctrl-C oder durch Schließen des Fensters."

while true; do
  for req in "$queue/requests"/*.request; do
    [ -e "$req" ] || continue
    name=$(basename "$req" .request)
    mode=$(head -c 32 "$req" | tr -d '[:space:]')
    rm -f "$req"
    # Nur einfache Namen, damit Status und Log nicht außerhalb von logs/ landen
    if [[ ! "$name" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
      echo "$(date '+%H:%M:%S') abgelehnt: ungültiger Auftragsname"
      continue
    fi
    if [ -e "$queue/logs/status-$name.txt" ]; then
      echo "$(date '+%H:%M:%S') abgelehnt: Name $name schon benutzt"
      continue
    fi
    log="$queue/logs/$name.log"
    write_status "$name" laeuft
    {
      echo "Auftrag $name · Modus $mode · $(date '+%d.%m.%Y %H:%M:%S') · Zeitlimit $(limit_for "$mode") s"
      echo "SHA-256 der Skripte:"
      shasum -a 256 Scripts/*.sh build/skript.sh build/m*/*.sh build/u1/*.sh 2>/dev/null
      if [ "$mode" = skript ]; then echo "--- build/skript.sh ---"; cat build/skript.sh; fi
      echo "---"
    } > "$log"
    echo "$(date '+%H:%M:%S') $name: $mode …"
    # stdin aus /dev/null: mit `set -m` bekäme der Auftrag sonst das Terminal und hielte bei einer Rückfrage an (SIGTTIN)
    bash Scripts/build.sh "$mode" < /dev/null >> "$log" 2>&1 &
    job=$!
    ( sleep "$(limit_for "$mode")"
      echo "Zeitlimit erreicht – Auftrag abgebrochen." >> "$log"
      kill -TERM -"$job" 2>/dev/null; sleep 10; kill -KILL -"$job" 2>/dev/null ) &
    watchdog=$!
    wait "$job"
    code=$?
    kill -- -"$watchdog" 2>/dev/null   # ganze Gruppe, auch das wartende sleep
    wait "$watchdog" 2>/dev/null
    write_status "$name" "$code"
    echo "$(date '+%H:%M:%S') $name: fertig (Exit $code)"
  done
  sleep 2
done
