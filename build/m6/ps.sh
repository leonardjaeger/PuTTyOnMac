#!/bin/bash
# Laufende Debug-Instanzen der App mit Startzeit (ohne Pfade mit Benutzernamen)
for pid in $(pgrep -f 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do echo "$pid $(ps -o lstart= -p "$pid")"; done
