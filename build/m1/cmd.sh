#!/bin/bash
# M1 Nachkontrolle: App beendet, PuTTY-Ordner leer und privat, Rechte
d="$HOME/Library/Application Support/TunnelTerminal/putty"
echo "App-Prozesse: $(pgrep -f 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | wc -l)"
stat -f '%Lp %N' "$d" "$d/sessions" | sed "s#$HOME#~#"
echo "Sitzungen: $(ls -A "$d/sessions" | wc -l)"
ls -A "$d" | sed 's/^/  /'
