#!/bin/bash
# M3-Oberflächenprüfung (Bauwächter, Modus skript). Aufruf über build/m3/schritt.txt: „ui <schritt>“
#   start      – Testserver 127.0.0.1:2222 (nur Schlüssel, build/m1/testserver.sh) ohne dessen Agent für die App,
#                Testsitzung „M3-Test“ im PuTTY-Ordner der App (Benutzer zur Laufzeit, nie im Repo oder Log, S14), Debug-App
#   schluessel – Wegwerf-Schlüssel test.ppk (ohne Passphrase) im Cache, öffentlicher Teil in die authorized_keys des Testservers
#   zeige      – Testsitzung ohne UserName-Zeile, Rechte im PuTTY-Ordner, bekannte Hostschlüssel für 127.0.0.1:2222
#   sitzung-schluessel – PublicKeyFile der Testsitzung auf test.ppk · neustart – neuen Debug-Build starten
#   gss        – GSSAPI-Prüfung der eingebauten Werkzeuge · kopf – Zeilen in sshhostkeys (nur Typ@Port)
#   stop       – App beenden, Testsitzung und Testserver entfernen
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
app="$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
ui="$cache/m3-ui"
case "${1:-}" in
  start)
    bash build/m1/testserver.sh start | grep -v "Agent-Socket"
    printf 'Present=1\nHostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nTerminalType=xterm-256color\n' "$(id -un)" \
      > "$putty/sessions/M3-Test" && chmod 600 "$putty/sessions/M3-Test" && echo "Testsitzung angelegt"
    open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | sed "s#$HOME#~#"
    ;;
  schluessel)
    mkdir -p "$ui"; chmod 700 "$ui"; rm -f "$ui/test.ppk"
    "$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/Helpers/puttygen" -t ed25519 -C m3-ui-test -q \
      -o "$ui/test.ppk" --new-passphrase /dev/null </dev/null && echo "test.ppk erzeugt"
    "$app/Contents/Helpers/puttygen" "$ui/test.ppk" -L >> "$cache/m1-testserver/authorized_keys" && echo "in authorized_keys eingetragen"
    ;;
  zeige)
    grep -v '^UserName=' "$putty/sessions/M3-Test"
    stat -f '%Lp %N' "$putty" "$putty/sshhostkeys" "$putty/sessions/M3-Test" | sed "s#$HOME#~#"
    grep '@2222:127.0.0.1 ' "$putty/sshhostkeys" | cut -c1-60
    ssh-keygen -lf "$cache/m1-testserver/host_ed25519.pub" | cut -d' ' -f1-2
    ;;
  sitzung-schluessel)
    # wie „Schlüsseldatei wählen …“ im Editor: PublicKeyFile der Testsitzung auf test.ppk
    printf 'PublicKeyFile=%s\n' "$ui/test.ppk" >> "$putty/sessions/M3-Test" && echo "Schlüsseldatei eingetragen"
    ;;
  neustart)
    # neuer Debug-Build (nach go.sh test) statt der laufenden App; Sitzung und Testserver bleiben
    for pid in $(pgrep -f 'TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do kill -TERM "$pid"; done
    sleep 1; open -n "$app"; sleep 2; pgrep -fl 'TunnelTerminal.app/Contents/MacOS/TunnelTerminal' | sed "s#$HOME#~#"
    bash build/m1/testserver.sh status 2>/dev/null | grep -v "Agent-Socket" || true
    ;;
  gss)
    # GSSAPI abgeschaltet? Version, Bibliotheken, Zeichenketten der eingebauten Werkzeuge
    for tool in plink puttygen; do
      "$app/Contents/Helpers/$tool" -V 2>&1 | head -1
      otool -L "$app/Contents/Helpers/$tool" | tail -n +2
      printf '%s: gssapi-Zeichenketten %s\n' "$tool" "$(strings "$app/Contents/Helpers/$tool" | grep -ci gssapi)"; strings "$app/Contents/Helpers/$tool" | grep -i "gss" | sort -u | head -12
    done
    du -sh "$app" | cut -f1
    ;;
  heim)
    # Diagnose „Heimserver verbindet nicht“: nur lesen und Verbindungsversuche, nichts am Server ändern.
    # Adresse zur Laufzeit (2. Wort in schritt.txt, sonst aus der Sitzung), in der Ausgabe als <server> maskiert (S14).
    f="$putty/sessions/Heimserver"
    host="${2:-$(sed -n 's/^HostName=//p' "$f" | tr -d '\r')}"; m() { sed "s#$host#<server>#g; s#$(id -un)#<ich>#g; s#$HOME#~#g"; }
    grep -E '^(Protocol|PortNumber|PublicKeyFile|ProxyMethod|LogicalHostName)=' "$f"
    echo "--- Route"; route -n get "$host" 2>&1 | grep -E 'interface|gateway' | m
    echo "--- TCP 22"; nc -z -G 6 -w 6 "$host" 22 >/dev/null 2>&1; echo "nc exit $? (0 = Port offen)"
    echo "--- Gegenprobe: ausgehend Port 22 überhaupt offen? (github.com:22)"; nc -z -G 6 -w 6 github.com 22 >/dev/null 2>&1; echo "nc exit $?"
    echo "--- github.com:443 (Netz allgemein)"; nc -z -G 6 -w 6 github.com 443 >/dev/null 2>&1; echo "nc exit $?"
    echo "--- ping"; ping -c 2 -t 4 "$host" >/dev/null 2>&1; echo "ping exit $? (0 = antwortet)"
    echo "--- plink -ssh -v -batch (nimmt keinen Hostschlüssel an, meldet sich nicht an)"
    PUTTYDIR="$putty" perl -e 'alarm 25; exec @ARGV' "$app/Contents/Helpers/plink" -ssh -P 22 -v -batch "$host" </dev/null 2>&1 | head -30 | m
    echo "plink exit ${PIPESTATUS[0]}"
    ;;
  kopf)
    # nur Typ@Port je Zeile und Zeilenzahl, ohne Server und Schlüssel
    wc -l < "$putty/sshhostkeys"; cut -d: -f1 "$putty/sshhostkeys" | sort | uniq -c; od -c "$putty/sshhostkeys" | head -2 | cut -c1-40
    ;;
  stop)
    for pid in $(pgrep -f 'TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/MacOS/TunnelTerminal'); do kill -TERM "$pid"; done
    rm -f "$putty/sessions/M3-Test"; rm -rf "$ui"
    bash build/m1/testserver.sh stop
    ;;
  *) echo "Aufruf: ui.sh start|schluessel|sitzung-schluessel|zeige|kopf|gss|neustart|stop"; exit 64 ;;
esac
