#!/bin/bash
# Beendet genau eine ältere Debug-Instanz (PID als Wert), nur wenn sie wirklich TunnelTerminal aus DerivedData ist (Leonard: ja, 20.10.2026)
pid="$1"
ps -p "$pid" -o command= | grep -q 'TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/MacOS/TunnelTerminal' \
  && kill -TERM "$pid" && sleep 2 && echo "beendet: $pid"
for p in $(pgrep -f 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do echo "läuft: $p $(ps -o lstart= -p "$p")"; done
