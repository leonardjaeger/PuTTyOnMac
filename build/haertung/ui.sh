#!/bin/bash
# Härtung: Laufzeitprüfung und Messung mit der Debug-App (Bauwächter, Modus skript). Aufruf über build/haertung/schritt.txt:
#   „ui start“    – Testserver 127.0.0.1:2222 (nur Schlüssel), Wegwerf-Schlüssel, Testsitzungen „Härtung/Mac“ (mit
#                   Sitzungsprotokoll), „Härtung/Viel“ (Fernbefehl mit viel Ausgabe) und „Härtung/Passwort“ (Prüfwort im
#                   Schlüsselbund, nur für die Debug-App freigegeben), Hostschlüssel wie mit „y“ angenommen, Debug-App starten
#   „ui pruefen“  – Prüfwort darf nirgends stehen außer im Schlüsselbund: Prozessliste, Umgebung, PuTTY-Ordner,
#                   Einstellungen, Sitzungsprotokolle, Systemprotokoll, Absturzberichte, Fensterzustand; offene Deskriptoren
#                   der plink-Prozesse
#   „ui profil <s>“ – Time Profiler an die laufende Debug-App hängen; danach mögliche Hänger (> 100 ms) auswerten
#   „ui stop“     – alles beenden und entfernen (Sitzungen, Schlüsselbund-Eintrag, eigene Hostschlüssel-Zeile, Testserver)
# Benutzername nur zur Laufzeit, Ausgabe maskiert (S14). Das Prüfwort ist zufällig und steht nur im Cache-Ordner.
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
app="$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
ui="$cache/haertung-ui"
bundle=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)
service="$bundle.passwort"
maske() { sed "s#$HOME#~#g; s#$(id -un)#BENUTZER#g"; }
# Beendet nur App-Instanzen aus dem Bau-Cache (nie eine installierte App) und keine, in der eine eigene Verbindung des
# Benutzers läuft (ein Kindprozess ohne „-load Härtung/…“) – die bleibt mit Hinweis offen
beende() {
  local pid k fremd
  for pid in $(pgrep -f "$cache/.*TunnelTerminal[.]app/Contents/MacOS/TunnelTerminal"); do
    fremd=0
    for k in $(pgrep -P "$pid"); do ps -o command= -p "$k" | grep -q -- '-load Härtung/' || fremd=$((fremd + 1)); done
    if [ "$fremd" -gt 0 ]; then echo "App $pid nicht beendet: $fremd eigene Verbindung(en) darin – selbst beenden"; continue; fi
    kill -TERM "$pid"
  done
}
sitzung() {   # $1 Dateiname, Rest: zusätzliche Zeilen
  local name="$1"; shift
  { printf 'Present=1\nHostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nTerminalType=xterm-256color\n' "$(id -un)"
    printf 'PublicKeyFile=%s\n' "$ui/test.ppk"
    for zeile in "$@"; do printf '%s\n' "$zeile"; done; } > "$putty/sessions/$name"
  chmod 600 "$putty/sessions/$name"
}
case "${1:-}" in
  start)
    [ -n "$bundle" ] || { echo "Debug-App fehlt – zuerst bauen"; exit 2; }
    mkdir -p "$ui"; chmod 700 "$ui"
    bash build/m1/testserver.sh start | grep -v "Agent-Socket"
    rm -f "$ui/test.ppk"
    "$app/Contents/Helpers/puttygen" -t ed25519 -C haertung-test -q -o "$ui/test.ppk" --new-passphrase /dev/null </dev/null
    "$app/Contents/Helpers/puttygen" "$ui/test.ppk" -L >> "$cache/m1-testserver/authorized_keys" && echo "Schlüssel eingetragen"
    mkdir -p "$putty/sessions"; chmod 700 "$putty" "$putty/sessions"
    sitzung "H%C3%A4rtung%2FMac" "LogType=2"
    sitzung "H%C3%A4rtung%2FViel" "RemoteCommand=seq 1 400000; sleep 30"
    sitzung "H%C3%A4rtung%2FPasswort" "LogType=2"
    # Prüfwort: zufällig, nur im Cache-Ordner (0600) und im Schlüsselbund; an „benutzer@server:port“ gebunden wie die App
    head -c 18 /dev/urandom | base64 | tr -d '/+=' | sed 's/^/HTpruef/' > "$ui/pruefwort"; chmod 600 "$ui/pruefwort"
    security delete-generic-password -s "$service" -a "Härtung/Passwort" >/dev/null 2>&1
    security add-generic-password -s "$service" -a "Härtung/Passwort" -G "$(id -un)@127.0.0.1:2222" \
      -l "TunnelTerminal: Härtung/Passwort" -T "$app" -w "$(cat "$ui/pruefwort")" && echo "Prüfwort im Schlüsselbund"
    printf 'y\n' | PUTTYDIR="$putty" perl -e 'use POSIX; POSIX::setsid(); alarm 20; exec @ARGV' \
      "$app/Contents/Helpers/plink" -load "Härtung/Mac" exit 2>&1 | grep -ciE 'host key' | sed 's/^/  Hostschlüssel-Abfrage beantwortet: /'
    open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | maske
    ;;
  pruefen)
    wort=$(cat "$ui/pruefwort") || exit 2
    zaehle() { printf '%-44s %s\n' "$1" "$2"; }
    muster="[${wort:0:1}]${wort:1}"   # findet das Prüfwort, aber nicht die Argumente von grep selbst
    zaehle "Prozessliste (Argumente aller Prozesse)" "$(ps -axww -o args= | grep -c "$muster")"
    for pid in $(pgrep -f 'Contents/Helpers/(plink|pscp)'); do
      zaehle "Umgebung plink $pid" "$(ps -E -ww -p "$pid" -o command= | grep -c "$wort")"
      echo "  offene Deskriptoren plink $pid (FD/Typ):"; lsof -p "$pid" -a -d 0-20 2>/dev/null | awk 'NR>1 {print "   ", $4, $5}'
    done
    zaehle "PuTTY-Ordner der App" "$(grep -rlaF "$wort" "$putty" 2>/dev/null | wc -l | tr -d ' ')"
    zaehle "Einstellungen ($bundle)" "$(defaults export "$bundle" - 2>/dev/null | grep -c "$wort")"
    zaehle "Sitzungsprotokolle" "$(grep -rlaF "$wort" "$HOME/Library/Logs/TunnelTerminal" 2>/dev/null | wc -l | tr -d ' ')"
    zaehle "Systemprotokoll (30 min, inkl. debug)" "$(log show --last 30m --info --debug --predicate 'process == "TunnelTerminal" OR process == "plink"' 2>/dev/null | grep -c "$wort")"
    zaehle "Absturzberichte" "$(grep -rlaF "$wort" "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | wc -l | tr -d ' ')"
    zaehle "Fensterzustand/Caches der App" "$(grep -rlaF "$wort" "$HOME/Library/Saved Application State/$bundle.savedState" "$HOME/Library/Caches/$bundle" "$HOME/Library/HTTPStorages/$bundle" 2>/dev/null | wc -l | tr -d ' ')"
    zaehle "Schlüsselbund-Eintrag vorhanden" "$(security find-generic-password -s "$service" -a "Härtung/Passwort" >/dev/null 2>&1 && echo ja || echo nein)"
    echo "Rechte: $(stat -f '%Sp %N' "$putty" "$putty/sessions" "$HOME/Library/Logs/TunnelTerminal" 2>/dev/null | maske | tr '\n' ' ')"
    ls -la "$HOME/Library/Logs/TunnelTerminal" 2>/dev/null | tail -4 | cut -c1-11,30-
    ;;
  profil)
    pid=$(pgrep -f "$cache/.*TunnelTerminal[.]app/Contents/MacOS/TunnelTerminal" | head -1)
    [ -n "$pid" ] || { echo "App läuft nicht"; exit 2; }
    ps -o command= -p "$pid" | maske
    rm -rf "$ui/profil.trace"
    xcrun xctrace record --template 'Time Profiler' --attach "$pid" --time-limit "${2:-40}s" --output "$ui/profil.trace" 2>&1 | tail -2 | maske
    xcrun xctrace export --input "$ui/profil.trace" --toc 2>/dev/null | grep -oE 'schema="[a-z-]+"' | sort -u | tr '\n' ' '; echo
    xcrun xctrace export --input "$ui/profil.trace" --xpath '//table[@schema="potential-hangs"]' > "$ui/haenger.xml" 2>/dev/null
    echo "Mögliche Hänger (Dauer in ns, Art):"
    grep -oE '<duration[^>]*fmt="[^"]+"|<hang-type[^>]*fmt="[^"]+"' "$ui/haenger.xml" | sed -E 's/.*fmt="//; s/"$//' | paste - - | head -20
    echo "Anzahl: $(grep -c '<row' "$ui/haenger.xml")"
    ;;
  gefahr)   # Sitzungen für die Rückfragen der Härtung (nur Platzhalter, nichts wird ausgeführt, solange man abbricht)
    sitzung "H%C3%A4rtung%2FGefahr" "PreConnectCommand=echo harmlos %host" "ProxyMethod=4" "ProxyHost=127.0.0.1" "ProxyPort=9" \
      "ProxyTelnetCommand=HELO test\\r\\n" "X11Forward=1" "X11Display=/tmp/haertung-x11-nicht-vorhanden:0"
    sitzung "H%C3%A4rtung%2FSocket" "PortForwardings=R2299=/tmp/haertung-nicht-vorhanden.sock:1"
    ls "$putty/sessions" | grep -c 'H%C3%A4rtung'
    # Fremder PuTTY-Ordner für die Importvorschau (nur Platzhalter)
    mkdir -p "$ui/import/sessions"
    printf 'HostName=server.example\nProtocol=ssh\nPreConnectCommand=touch /tmp/x\n' > "$ui/import/sessions/Mit%20Befehl"
    printf 'HostName=server.example\nProtocol=ssh\nUserName=test\n' > "$ui/import/sessions/Harmlos"
    echo "Importordner: ~/Library/Caches/TunnelTerminal-Build/haertung-ui/import"
    ;;
  neustart)   # die zuletzt gestartete Fassung (Release zum Messen, sonst Debug) neu starten
    beende; sleep 1
    rel="$cache/ReleaseProfil/Build/Products/Release/TunnelTerminal.app"
    if [ -d "$rel" ]; then open -n "$rel"; else open -n "$app"; fi; sleep 2
    pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | maske
    ;;
  relstart)   # Release-Bau zum Messen (wie die Weitergabe, aber mit get-task-allow, damit xctrace sich anhängen darf)
    beende; sleep 1
    xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj -scheme TunnelTerminal -configuration Release \
      -destination 'platform=macOS' -derivedDataPath "$cache/ReleaseProfil" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=YES build \
      > "$ui/relbau.log" 2>&1 || { grep -E 'error:' "$ui/relbau.log" | maske | head; exit 1; }
    open -n "$cache/ReleaseProfil/Build/Products/Release/TunnelTerminal.app"; sleep 2
    pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | maske
    ;;
  haenger)   # Hauptthread-Stapel während der möglichen Hänger aus „profil“ (build/haertung/haenger.py, lokal)
    xcrun xctrace export --input "$ui/profil.trace" --xpath '//table[@schema="time-profile"]' > "$ui/zeit.xml" 2>/dev/null
    python3 build/haertung/haenger.py "$ui/haenger.xml" "$ui/zeit.xml" | maske
    ;;
  stop)
    beende
    rm -f "$putty/sessions"/H%C3%A4rtung%2F*
    security delete-generic-password -s "$service" -a "Härtung/Passwort" >/dev/null 2>&1 && echo "Schlüsselbund-Eintrag entfernt"
    if [ -f "$putty/sshhostkeys" ]; then   # nur die eigene Zeile „…@2222:127.0.0.1 …“
      grep -v '@2222:127\.0\.0\.1 ' "$putty/sshhostkeys" > "$ui/sshhostkeys.neu"
      cat "$ui/sshhostkeys.neu" > "$putty/sshhostkeys"
    fi
    for t in Mac Passwort Viel Gefahr Socket; do   # nur die Protokolle der eigenen Testsitzungen „Härtung/…“
      for f in "$HOME/Library/Logs/TunnelTerminal"/H*rtung-"$t"\ 20*.log; do [ -e "$f" ] && rm -f "$f" && echo "Protokoll entfernt"; done
    done
    rm -rf "$ui" "$cache/ReleaseProfil"
    bash build/m1/testserver.sh stop
    ;;
  *) echo "Aufruf: ui.sh start|pruefen|profil [s]|stop"; exit 64 ;;
esac
