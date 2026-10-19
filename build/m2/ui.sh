#!/bin/bash
# M2-Oberflächenprüfung (läuft über den Bauwächter auf dem Mac). Aufruf: ui.sh start|ordner|stop
#   start  – Testserver (127.0.0.1:2222, build/m1/testserver.sh) und Debug-App mit dessen ssh-agent starten
#   ordner – Sitzungen im PuTTY-Ordner der App mit Rechten (Namen sind Testnamen ohne persönliche Daten)
#   stop   – App beenden, Testserver stoppen
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
app="$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
case "${1:-}" in
  start)
    bash build/m1/testserver.sh start
    open -n --env "SSH_AUTH_SOCK=$cache/m1-testserver/agent.sock" "$app"
    sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | sed "s#$HOME#~#"
    ;;
  ordner)
    stat -f '%Lp %N' "$putty" "$putty/sessions" | sed "s#$HOME#~#"
    for f in "$putty/sessions"/*; do [ -e "$f" ] && stat -f '%Lp %z %N' "$f" | sed "s#$putty/sessions/##"; done
    ;;
  zeige)
    # nur die in der Prüfung angelegte Testsitzung (Platzhalter, S14)
    cat "$putty/sessions/Neue%20Sitzung"
    ;;
  gefahr)
    # Testsitzung mit lokalem Proxy-Befehl für die S4-Rückfrage (nur Platzhalter, S14); „gefahr-weg“ entfernt sie
    printf 'HostName=server.example\nProtocol=ssh\nPortNumber=22\nProxyMethod=5\nProxyTelnetCommand=echo Testbefehl\n' \
      > "$putty/sessions/Gefahr%20Test" && chmod 600 "$putty/sessions/Gefahr%20Test" && echo angelegt
    ;;
  gefahr-weg)
    rm -f "$putty/sessions/Gefahr%20Test" && echo entfernt
    ;;
  stop)
    # alle laufenden Debug-Builds (auch ältere Instanzen) regulär beenden
    for pid in $(pgrep -f 'TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do
      kill -TERM "$pid"
    done
    sleep 1; pgrep -fl 'TunnelTerminal.app/Contents/MacOS' | sed "s#$HOME#~#"
    bash build/m1/testserver.sh stop
    ;;
  *) echo "Aufruf: ui.sh start|ordner|zeige|gefahr|gefahr-weg|stop"; exit 64 ;;
esac
