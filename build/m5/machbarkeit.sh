#!/bin/bash
# M5-Machbarkeit (Bauwächter, Modus skript): Terminalmodus bei Seriell/Telnet/Raw, Port-Weiterleitungen, Proxys,
# Jump-Host. Wegwerf-sshd aus M1 auf 127.0.0.1:2222 (nur Schlüssel), eigener PuTTY-Ordner im Cache; Benutzername nur
# zur Laufzeit, nie ausgegeben (S14). Hostschlüssel nur hier im Testskript fest vorgegeben (SSHManualHostKeys).
# Aufruf über schritt.txt: „machbarkeit terminal|tunnel|alles“
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
p="${PLINK:-$cache/putty-0.85/bau/plink}"
srv="$cache/m1-testserver"
d="$cache/m5-machbarkeit"; rm -rf "$d"; mkdir -p "$d/putty/sessions"; chmod -R 700 "$d"
"$p" -V | head -1
ohne_tty() { perl -e 'use POSIX; POSIX::setsid(); alarm 25; exec @ARGV or exit 127' "$@"; }

terminal() {
  echo "== Seriell (PTY-Paar als Gerät)"; python3 build/m5/probe.py serial "$p" "$d/putty"
  echo "== Telnet (Server verhandelt ECHO + SGA)"; python3 build/m5/probe.py telnet "$p" "$d/putty"
  echo "== Raw"; python3 build/m5/probe.py raw "$p" "$d/putty"
}

tunnel() {
  bash build/m1/testserver.sh start >/dev/null 2>&1
  fp=$(ssh-keygen -lf "$srv/host_ed25519.pub" -E sha256 | cut -d' ' -f2)
  basis() { printf 'HostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nSSHManualHostKeys=%s\n%b' "$(id -un)" "$fp" "${1:-}"; }
  export PUTTYDIR="$d/putty" SSH_AUTH_SOCK="$srv/agent.sock"
  mkdir -p "$d/www"; echo "WEB-OK" > "$d/www/index.html"
  python3 -m http.server 28081 --bind 127.0.0.1 --directory "$d/www" >/dev/null 2>&1 & web=$!
  sleep 1
  echo "== Weiterleitungen L28080, D28082, R28083 (PortForwardings, Format wie settings.c)"
  basis 'PortForwardings=L28080=127.0.0.1:28081,D28082,R28083=127.0.0.1:28081\n' > "$d/putty/sessions/fw"
  ohne_tty "$p" -load fw -N < /dev/null > "$d/fw.out" 2>&1 & fw=$!
  sleep 3
  printf '  lokal:     %s\n' "$(curl -s -m 5 http://127.0.0.1:28080/ || echo FEHLER)"
  printf '  dynamisch: %s\n' "$(curl -s -m 5 --socks5-hostname 127.0.0.1:28082 http://127.0.0.1:28081/ || echo FEHLER)"
  printf '  entfernt:  %s\n' "$(curl -s -m 5 http://127.0.0.1:28083/ || echo FEHLER)"
  echo "  Ausgabe von plink: $(tr '\r\n' '  ' < "$d/fw.out")"

  echo "== Proxy SOCKS 5 über die dynamische Weiterleitung"
  basis 'ProxyMethod=2\nProxyHost=127.0.0.1\nProxyPort=28082\nProxyLocalhost=1\n' > "$d/putty/sessions/socks"
  ohne_tty "$p" -load socks 'echo SOCKS-OK' < /dev/null 2>&1 | tr -d '\r' | sed 's/^/  /' | head -4
  echo "== Proxy HTTP (CONNECT, eigener Test-Proxy auf 28084)"
  python3 build/m5/probe.py httpproxy 28084 > "$d/http.out" 2>&1 & hp=$!; sleep 1
  basis 'ProxyMethod=3\nProxyHost=127.0.0.1\nProxyPort=28084\nProxyLocalhost=1\n' > "$d/putty/sessions/http"
  ohne_tty "$p" -load http 'echo HTTP-OK' < /dev/null 2>&1 | tr -d '\r' | sed 's/^/  /' | head -4
  echo "  Proxy sah: $(tr '\n' ' ' < "$d/http.out")"
  echo "== Jump-Host: Sitzung „Sprung/Mac“ als SSH-Proxy (ProxyMethod=6, ProxyHost=Sitzungsname)"
  basis '' > "$d/putty/sessions/Sprung%2FMac"
  basis 'ProxyMethod=6\nProxyHost=Sprung/Mac\nProxyLocalhost=1\n' > "$d/putty/sessions/ziel"
  ohne_tty "$p" -load ziel 'echo SPRUNG-OK' < /dev/null 2>&1 | tr -d '\r' | sed 's/^/  /' | head -6
  grep -c "Accepted publickey" "$srv/sshd.log" | sed 's/^/  Anmeldungen am sshd bisher: /'
  echo "== Lokaler Port schon belegt (28090): Was meldet plink?"
  python3 -c 'import socket,time; s=socket.socket(); s.bind(("127.0.0.1",28090)); s.listen(1); time.sleep(12)' & busy=$!; sleep 1
  basis 'PortForwardings=L28090=127.0.0.1:28081\n' > "$d/putty/sessions/busy"
  ohne_tty "$p" -load busy 'sleep 2; echo BELEGT-ENDE' < /dev/null 2>&1 | tr -d '\r' | sed 's/^/  ohne -v: /' | head -4
  ohne_tty "$p" -v -load busy "sleep 2; echo BELEGT-ENDE" < /dev/null 2>&1 | tr -d "\r" | grep -E "^Local port" | sed "s/^/  mit -v: /"
  kill $fw $web $hp $busy 2>/dev/null; wait 2>/dev/null
  bash build/m1/testserver.sh stop >/dev/null 2>&1
}

case "${1:-alles}" in
  terminal) terminal ;;
  tunnel) tunnel ;;
  alles) terminal; tunnel ;;
esac
rm -rf "$d"
