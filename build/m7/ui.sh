#!/bin/bash
# M7-Oberflächenprüfung (Bauwächter, Modus skript). Aufruf über build/m7/schritt.txt: „ui <schritt> [wert]“
#   start [hell|dunkel] – Testserver 127.0.0.1:2222 (nur Schlüssel), Wegwerf-Schlüssel, Testsitzungen „M7/Mac“ und
#                         „M7/Telnet“ (nur Platzhalter), Hostschlüssel wie mit „y“ angenommen, Debug-App starten.
#                         hell/dunkel setzt das Erscheinungsbild nur für diese App (keine Systemeinstellung).
#   neustart [hell|dunkel] · link <url> – Link über die Standard-App öffnen (wie aus Safari) · linkapp <url> – direkt an die
#   Debug-App · handler – Standard-Apps
#   stop – alles beenden und entfernen. Benutzer nur zur Laufzeit, nie im Repo oder Log (S14).
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
app="$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
ui="$cache/m7-ui"
maske() { sed "s#$HOME#~#g; s#$(id -un)#BENUTZER#g"; }
beende() { for pid in $(pgrep -f 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do kill -TERM "$pid"; done; }
starte() {
  case "${1:-}" in
    dunkel) open -n "$app" --args -AppleInterfaceStyle Dark ;;
    hell) open -n "$app" --args -NSRequiresAquaSystemAppearance YES ;;
    *) open -n "$app" ;;
  esac
  sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | maske
}
case "${1:-}" in
  start)
    mkdir -p "$ui"; chmod 700 "$ui"
    bash build/m1/testserver.sh start | grep -v "Agent-Socket"
    rm -f "$ui/test.ppk"
    "$app/Contents/Helpers/puttygen" -t ed25519 -C m7-ui-test -q -o "$ui/test.ppk" --new-passphrase /dev/null </dev/null
    "$app/Contents/Helpers/puttygen" "$ui/test.ppk" -L >> "$cache/m1-testserver/authorized_keys" && echo "Schlüssel eingetragen"
    mkdir -p "$putty/sessions"; chmod 700 "$putty" "$putty/sessions"
    printf 'Present=1\nHostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nTerminalType=xterm-256color\nPublicKeyFile=%s\nPortForwardings=L8080=localhost:80\n' \
      "$(id -un)" "$ui/test.ppk" > "$putty/sessions/M7%2FMac" && chmod 600 "$putty/sessions/M7%2FMac"
    printf 'Present=1\nHostName=192.0.2.10\nProtocol=telnet\nPortNumber=23\n' > "$putty/sessions/M7%2FTelnet" && chmod 600 "$putty/sessions/M7%2FTelnet"
    printf 'y\n' | PUTTYDIR="$putty" perl -e 'use POSIX; POSIX::setsid(); alarm 20; exec @ARGV' \
      "$app/Contents/Helpers/plink" -load "M7/Mac" exit 2>&1 | grep -ciE 'host key' | sed 's/^/  Hostschlüssel-Abfrage beantwortet: /'
    starte "${2:-}"
    ;;
  neustart) beende; sleep 1; starte "${2:-}" ;;
  link) open "${2:?Link fehlt}"; echo "geöffnet: ${2}" ;;
  linkapp) open -a "$app" "${2:?Link fehlt}"; echo "an die Debug-App gegeben: ${2}" ;;
  dmg) bash Scripts/build.sh dmg ;;
  hilfe) bash Scripts/kurzanleitung.sh ${2:-} ;;   # Kurzanleitung.rtf aus der HTML-Quelle (--pruefen: nur vergleichen)
  snap)   # Bilder der Menü-Fenster in Hell/Dunkel nach ~/Library/Caches/TunnelTerminal-Build/m7-snap (SnapshotTests)
    rm -rf "$cache/m7-snap"
    TEST_RUNNER_TUNNELTERMINAL_SNAPSHOTS="$cache/m7-snap" xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj \
      -scheme TunnelTerminal -destination 'platform=macOS' -derivedDataPath "$cache/DerivedData" test \
      -only-testing:TunnelTerminalTests/SnapshotTests > "$cache/m7-snap.log" 2>&1
    code=$?; grep -E "error:|skipped|passed|failed|TEST (SUCCEEDED|FAILED)" "$cache/m7-snap.log" | grep -v linkd | maske | tail -8
    ls "$cache/m7-snap" 2>/dev/null; exit $code
    ;;   # bis zum Neustart des Bauwächters über „skript“ (Zeitlimit 15 min)
  messen)   # Release-App aus dem DMG-Bau: Start, Speicher und CPU im Leerlauf (Richtlinien 2.4: in der fertigen App messen)
    rel="$cache/Release/Build/Products/Release/TunnelTerminal.app"
    beende; sleep 1
    t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
    open -n "$rel"
    for i in $(seq 1 100); do
      pid=$(pgrep -f 'Release/TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | head -1)
      [ -n "$pid" ] && lsappinfo info -only pid "$pid" >/dev/null 2>&1 && break; sleep 0.05
    done
    t1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
    echo "Prozess nach $(echo "$t1 - $t0" | bc) s"
    sleep 6
    ps -o %cpu=,rss= -p "$pid" | awk '{printf "CPU im Leerlauf %s %%, RSS %.1f MB\n", $1, $2/1024}'
    footprint -p "$pid" 2>/dev/null | grep -E "phys_footprint:|Footprint" | head -3 | maske
    du -sh "$rel" | maske
    kill -TERM "$pid"
    ;;
  handler)
    defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers 2>/dev/null \
      | grep -B1 -A3 -E 'LSHandlerURLScheme = (ssh|telnet)' | maske
    ;;
  stop)
    beende
    rm -f "$putty/sessions"/M7%2F*
    # Nur den eigenen Test-Hostschlüssel aus „start“ entfernen (Zeile „…@2222:127.0.0.1 …“), alle anderen bleiben
    if [ -f "$putty/sshhostkeys" ]; then
      grep -v '@2222:127\.0\.0\.1 ' "$putty/sshhostkeys" > "$ui/sshhostkeys.neu"
      cat "$ui/sshhostkeys.neu" > "$putty/sshhostkeys"
    fi
    rm -rf "$ui"
    bash build/m1/testserver.sh stop
    ;;
  *) echo "Aufruf: ui.sh start|neustart [hell|dunkel]|link <url>|handler|stop"; exit 64 ;;
esac
