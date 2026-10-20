#!/bin/bash
# M4-Oberflächenprüfung (Bauwächter, Modus skript). Aufruf über build/m4/schritt.txt: „ui <schritt>“
#   start   – Testserver 127.0.0.1:2222 (nur Schlüssel, build/m1/testserver.sh), Wegwerf-Schlüssel test.ppk, Testsitzungen
#             „M4/Test“ und „M4/Tempo“ (RemoteCommand misst den Durchsatz) im PuTTY-Ordner der App, Debug-App starten.
#             Benutzer nur zur Laufzeit, nie im Repo oder Log (S14).
#   neustart – neuen Debug-Build starten · protokolle – Sitzungsprotokolle (Name, Rechte, Größe; Suchwort als 2. Wort)
#   tempo-log – „M4/Tempo“ mit Sitzungsprotokoll · stop – App beenden, Testsitzungen, Protokolle der Tests, Testserver weg
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
app="$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
logs="$HOME/Library/Logs/TunnelTerminal"
ui="$cache/m4-ui"
sitzung() {  # $1 = Dateiname, $2 = zusätzliche Zeilen
  printf 'Present=1\nHostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nTerminalType=xterm-256color\nPublicKeyFile=%s\n%b' \
    "$(id -un)" "$ui/test.ppk" "${2:-}" > "$putty/sessions/$1" && chmod 600 "$putty/sessions/$1"
}
beende() { for pid in $(pgrep -f 'TunnelTerminal-Build/(DerivedData|ReleaseCheck)/Build/Products/(Debug|Release)/TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do kill -TERM "$pid"; done; }
case "${1:-}" in
  start)
    bash build/m1/testserver.sh start | grep -v "Agent-Socket"
    mkdir -p "$ui"; chmod 700 "$ui"; rm -f "$ui/test.ppk"
    "$app/Contents/Helpers/puttygen" -t ed25519 -C m4-ui-test -q -o "$ui/test.ppk" --new-passphrase /dev/null </dev/null
    "$app/Contents/Helpers/puttygen" "$ui/test.ppk" -L >> "$cache/m1-testserver/authorized_keys" && echo "Schlüssel eingetragen"
    sitzung "M4%2FTest"
    # Durchsatz: 2 Mio. Zeilen (ca. 15 MB); die Zeit misst der Server, sie hängt am Lesetempo des Terminals
    sitzung "M4%2FTempo" 'RemoteCommand=/usr/bin/time -p /usr/bin/seq 1 2000000\n'
    echo "Testsitzungen angelegt"
    open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | sed "s#$HOME#~#"
    ;;
  hostkey)
    # Hostschlüssel des Wegwerf-Servers (127.0.0.1:2222, nach jedem Start neu) annehmen wie mit „y“ in plinks Abfrage
    printf 'y\n' | PUTTYDIR="$putty" perl -e 'use POSIX; POSIX::setsid(); alarm 20; exec @ARGV' \
      "$app/Contents/Helpers/plink" -load "M4/Test" exit 2>&1 | grep -iE 'key|cache' | head -3; echo "plink exit ${PIPESTATUS[1]}"
    ;;
  absturz)
    # letzter Absturzbericht der App (nur Ausnahme und die ersten Rahmen des abgestürzten Threads, Pfade gekürzt)
    f=$(ls -t "$HOME/Library/Logs/DiagnosticReports"/TunnelTerminal-*.ips 2>/dev/null | head -1); [ -n "$f" ] || { echo "kein Bericht"; exit 0; }
    echo "$(basename "$f")"
    python3 -c 'import json,sys; t=open(sys.argv[1]).read().split("\n",1)[1]; d=json.loads(t); print(d.get("exception")); print(d.get("termination",{}).get("indicator")); th=[x for x in d["threads"] if x.get("triggered")][0]; imgs=d["usedImages"]; [print(i, imgs[fr["imageIndex"]].get("name"), fr.get("symbol")) for i,fr in enumerate(th["frames"][:25])]' "$f" | sed "s#$HOME#~#g"
    ;;
  release)
    # Release-Bau (SwiftTerm optimiert, wie die spätere Weitergabe) für die Tempo-Prüfung; startet statt der Debug-App
    dd="$cache/ReleaseCheck"
    xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj -scheme TunnelTerminal -configuration Release \
      -destination 'platform=macOS' -derivedDataPath "$dd" build > "$dd.log" 2>&1; echo "xcodebuild Exit $?"
    beende; sleep 1
    open -n "$dd/Build/Products/Release/TunnelTerminal.app"; sleep 2; pgrep -fl 'Release/TunnelTerminal.app' | sed "s#$HOME#~#"
    ;;
  tempo-log)
    sitzung "M4%2FTempo" 'RemoteCommand=/usr/bin/time -p /usr/bin/seq 1 2000000\nLogType=2\n'; echo "Tempo mit Protokoll"
    ;;
  neustart)
    beende; sleep 1; open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | sed "s#$HOME#~#"
    ;;
  protokolle)
    stat -f '%Lp %z %N' "$logs" "$logs"/* 2>&1 | sed "s#$HOME#~#"
    [ -n "${2:-}" ] && for f in "$logs"/*; do printf '%s: %s Treffer für das Suchwort\n' "$(basename "$f")" "$(grep -c -- "$2" "$f")"; done
    ;;
  stop)
    beende
    rm -f "$putty/sessions/M4%2FTest" "$putty/sessions/M4%2FTempo" "$logs"/M4-Test\ * "$logs"/M4-Tempo\ *; rm -rf "$ui"
    bash build/m1/testserver.sh stop
    ;;
  *) echo "Aufruf: ui.sh start|tempo-log|neustart|protokolle [wort]|stop"; exit 64 ;;
esac
