#!/bin/bash
# M0 Schritt 5: Während eine Prototyp-Verbindung offen ist – erscheint das Passwort in der Prozessliste?
# Welche Dateideskriptoren hat plink geerbt?
# Spalte TTY: "??" = plink hat kein Steuerterminal (wichtig für Fenstergröße in Weg B).
echo "== plink-Prozesse mit vollständigen Argumenten =="
ps -axww -o pid=,ppid=,tty=,stat=,command= | grep '[p]link' || echo "kein plink läuft"
for pid in $(pgrep -x plink); do
  echo "== Offene Deskriptoren von plink $pid =="
  lsof -n -P -p "$pid" -a -d '0-255' 2>/dev/null | awk 'NR==1 || $4 ~ /^[0-9]+/'
  echo "== Umgebung (nur Namen) =="
  ps -E -ww -o command= -p "$pid" | tr ' ' '\n' | grep -E '^[A-Z_]+=' | cut -d= -f1 | sort -u | tr '\n' ' '; echo
done
