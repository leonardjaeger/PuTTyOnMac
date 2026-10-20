#!/bin/bash
# M5-Oberflächenprüfung (Bauwächter, Modus skript). Aufruf über build/m5/schritt.txt: „ui <schritt>“
#   start    – Testserver 127.0.0.1:2222 (nur Schlüssel), Wegwerf-Schlüssel, Testseite auf 127.0.0.1:28181,
#              Ersatzgerät für Seriell (PTY, echot in Großbuchstaben), Testsitzungen „M5/…“, Debug-App starten.
#              Benutzer nur zur Laufzeit, nie im Repo oder Log (S14).
#   hostkey  – Hostschlüssel des Wegwerf-Servers annehmen wie mit „y“ · curl – Weiterleitungen von außen prüfen
#   neustart – neuen Debug-Build starten · stop – alles beenden und Testsitzungen entfernen
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
app="$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
ui="$cache/m5-ui"
sitzung() {  # $1 = Dateiname, $2 = zusätzliche Zeilen
  printf 'Present=1\nHostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nTerminalType=xterm-256color\nPublicKeyFile=%s\n%b' \
    "$(id -un)" "$ui/test.ppk" "${2:-}" > "$putty/sessions/$1" && chmod 600 "$putty/sessions/$1"
}
beende() { for pid in $(pgrep -f 'TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do kill -TERM "$pid"; done; }
case "${1:-}" in
  start)
    bash build/m1/testserver.sh start | grep -v "Agent-Socket"
    mkdir -p "$ui/www"; chmod 700 "$ui"; rm -f "$ui/test.ppk"; echo "M5-TESTSEITE" > "$ui/www/index.html"
    "$app/Contents/Helpers/puttygen" -t ed25519 -C m5-ui-test -q -o "$ui/test.ppk" --new-passphrase /dev/null </dev/null
    "$app/Contents/Helpers/puttygen" "$ui/test.ppk" -L >> "$cache/m1-testserver/authorized_keys" && echo "Schlüssel eingetragen"
    nohup python3 -m http.server 28181 --bind 127.0.0.1 --directory "$ui/www" > /dev/null 2>&1 & echo $! > "$ui/web.pid"
    nohup python3 -c '
import os, pty, select, sys
m, s = os.openpty(); open(sys.argv[1], "w").write(os.ttyname(s))
while True:
    select.select([m], [], [])
    os.write(m, os.read(m, 1024).upper())' "$ui/geraet.txt" > /dev/null 2>&1 & echo $! > "$ui/geraet.pid"
    sleep 1
    sitzung "M5%2FMac"
    sitzung "M5%2FTunnel" 'PortForwardings=L28180=127.0.0.1:28181,D28182=\n'
    sitzung "M5%2FSprung" 'ProxyMethod=6\nProxyHost=M5/Mac\nProxyLocalhost=1\n'
    printf 'Present=1\nProtocol=serial\nSerialLine=%s\nSerialSpeed=115200\nSerialFlowControl=0\nTerminalType=xterm-256color\n' \
      "$(cat "$ui/geraet.txt")" > "$putty/sessions/M5%2FSeriell"; chmod 600 "$putty/sessions/M5%2FSeriell"
    echo "Testsitzungen angelegt"
    open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | sed "s#$HOME#~#"
    ;;
  hostkey)
    printf 'y\n' | PUTTYDIR="$putty" perl -e 'use POSIX; POSIX::setsid(); alarm 20; exec @ARGV' \
      "$app/Contents/Helpers/plink" -load "M5/Mac" exit 2>&1 | grep -iE 'key|cache' | head -3; echo "plink exit ${PIPESTATUS[1]}"
    ;;
  curl)
    printf 'lokal 28180:      %s\n' "$(curl -s -m 5 http://127.0.0.1:28180/ || echo FEHLER)"
    printf 'dynamisch 28182:  %s\n' "$(curl -s -m 5 --socks5-hostname 127.0.0.1:28182 http://127.0.0.1:28181/ || echo FEHLER)"
    grep -c "Accepted publickey" "$cache/m1-testserver/sshd.log" | sed 's/^/Anmeldungen am Testserver: /'
    ;;
  zeige)
    for f in "$putty/sessions"/M5*; do echo "== $(basename "$f")"; sed "s#$HOME#~#; s#^UserName=.*#UserName=(Benutzer)#" "$f"; done
    ;;
  neustart)
    beende; sleep 1; open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | sed "s#$HOME#~#"
    ;;
  stop)
    beende
    for p in web geraet; do [ -f "$ui/$p.pid" ] && kill "$(cat "$ui/$p.pid")" 2>/dev/null; done
    rm -f "$putty/sessions"/M5%2F*; rm -rf "$ui"
    bash build/m1/testserver.sh stop
    ;;
  *) echo "Aufruf: ui.sh start|hostkey|curl|zeige|neustart|stop"; exit 64 ;;
esac
