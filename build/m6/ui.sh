#!/bin/bash
# M6-Oberflächenprüfung und Ende-zu-Ende-Test (Bauwächter, Modus skript). Aufruf über build/m6/schritt.txt: „ui <schritt>“
#   start    – Testserver 127.0.0.1:2222 (nur Schlüssel, SFTP startet im Testordner „fern“ statt im Home),
#              Wegwerf-Schlüssel, Testsitzung „M6/Mac“, Hostschlüssel angenommen wie mit „y“, Debug-App starten.
#              Benutzer nur zur Laufzeit, nie im Repo oder Log (S14).
#   e2e      – FileTransferTests.testRealPscpAgainstTestServer mit dem eingebauten pscp gegen den Testserver
#   dateien  – Testdateien in „lokal“ (klein, 400 MB) und beide Ordner im Finder öffnen
#   zeige    – Inhalt der Testordner · neustart – Debug-App neu starten · stop – alles beenden und entfernen
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
app="$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
ui="$cache/m6-ui"
maske() { sed "s#$HOME#~#g; s#$(id -un)#BENUTZER#g"; }
beende() { for pid in $(pgrep -f 'TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do kill -TERM "$pid"; done; }
sitzung() {  # $1 = PuTTY-Ordner
  mkdir -p "$1/sessions"; chmod 700 "$1" "$1/sessions"
  printf 'Present=1\nHostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nTerminalType=xterm-256color\nPublicKeyFile=%s\n' \
    "$(id -un)" "$ui/test.ppk" > "$1/sessions/M6%2FMac" && chmod 600 "$1/sessions/M6%2FMac"
  printf 'y\n' | PUTTYDIR="$1" perl -e 'use POSIX; POSIX::setsid(); alarm 20; exec @ARGV' \
    "$app/Contents/Helpers/plink" -load "M6/Mac" exit 2>&1 | grep -ciE 'host key' | sed 's/^/  Hostschlüssel-Abfrage beantwortet: /'
}
case "${1:-}" in
  start)
    mkdir -p "$ui/fern/unterordner" "$ui/lokal"; chmod 700 "$ui"
    SFTP_START="$ui/fern" bash build/m1/testserver.sh start | grep -v "Agent-Socket"
    rm -f "$ui/test.ppk"
    "$app/Contents/Helpers/puttygen" -t ed25519 -C m6-ui-test -q -o "$ui/test.ppk" --new-passphrase /dev/null </dev/null
    "$app/Contents/Helpers/puttygen" "$ui/test.ppk" -L >> "$cache/m1-testserver/authorized_keys" && echo "Schlüssel eingetragen"
    echo "Inhalt vom Server" > "$ui/fern/vom-server.txt"
    dd if=/dev/urandom of="$ui/fern/gross.bin" bs=1048576 count=300 2>/dev/null
    sitzung "$putty"; echo "Testsitzung „M6/Mac“ angelegt"
    open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | maske
    ;;
  e2e)
    rm -rf "$ui/e2e"; mkdir -p "$ui/e2e/fern"; sitzung "$ui/e2e/putty"   # jeder Lauf mit leerem Testordner
    TEST_RUNNER_TUNNELTERMINAL_E2E="$ui/e2e" xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj \
      -scheme TunnelTerminal -destination 'platform=macOS' -derivedDataPath "$cache/DerivedData" test \
      -only-testing:TunnelTerminalTests/FileTransferTests/testRealPscpAgainstTestServer > "$cache/m6-e2e.log" 2>&1
    code=$?
    grep -E "error:|skipped|passed|failed|TEST (SUCCEEDED|FAILED)" "$cache/m6-e2e.log" | grep -v linkd | maske | tail -20
    grep -c "Accepted publickey" "$cache/m1-testserver/sshd.log" | sed 's/^/Anmeldungen am Testserver: /'
    echo "exit=$code"; exit $code
    ;;
  dateien)
    echo "Kleine Testdatei vom Mac" > "$ui/lokal/klein.txt"
    [ -f "$ui/lokal/gross.bin" ] || dd if=/dev/urandom of="$ui/lokal/gross.bin" bs=1048576 count=400 2>/dev/null
    open "$ui/lokal"; open "$ui/fern"; echo "Finder-Fenster „lokal“ (zum Ziehen) und „fern“ (Server-Seite) geöffnet"
    ;;
  zeige)
    for d in fern lokal; do echo "== $d"; ls -la "$ui/$d" 2>&1 | maske | tail -n +2; done
    ;;
  neustart)
    beende; sleep 1; open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | maske
    ;;
  stop)
    beende
    rm -f "$putty/sessions"/M6%2F*
    rm -rf "$ui"
    bash build/m1/testserver.sh stop
    ;;
  *) echo "Aufruf: ui.sh start|e2e|zeige|neustart|stop"; exit 64 ;;
esac
