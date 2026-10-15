#!/bin/bash
# M1 Nachkontrolle: App beendet, PuTTY-Ordner leer und privat, Rechte
d="$HOME/Library/Application Support/SSH-App/putty"
echo "App-Prozesse: $(pgrep -f 'SSH-App.app/Contents/MacOS/SSH-App' | wc -l)"
stat -f '%Lp %N' "$d" "$d/sessions" | sed "s#$HOME#~#"
echo "Sitzungen: $(ls -A "$d/sessions" | wc -l)"
ls -A "$d" | sed 's/^/  /'
