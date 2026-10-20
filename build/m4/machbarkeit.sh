#!/bin/bash
# M4-Machbarkeit (Bauwächter, Modus skript): Was schreibt plinks Sitzungsprotokoll (-sessionlog, LogType)?
# Wegwerf-sshd aus M1 auf 127.0.0.1:2222 (nur Schlüssel), eigener PuTTY-Ordner im Cache; Benutzername nur zur
# Laufzeit, nie ausgegeben (S14). Der Hostschlüssel wird nur hier im Testskript per -hostkey vorgegeben.
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
p="$cache/putty-0.85/bau/plink"
srv="$cache/m1-testserver"
d="$cache/m4-machbarkeit"; rm -rf "$d"; mkdir -p "$d/putty/sessions"; chmod -R 700 "$d"
bash build/m1/testserver.sh start >/dev/null 2>&1
fp=$(ssh-keygen -lf "$srv/host_ed25519.pub" -E sha256 | cut -d' ' -f2)
printf 'HostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\n' "$(id -un)" > "$d/putty/sessions/s"
ohne_tty() { perl -e 'use POSIX; POSIX::setsid(); alarm 20; exec @ARGV or exit 127' "$@"; }
lauf() {  # $1 = Name, Rest = zusätzliche Argumente
  local n="$1"; shift
  PUTTYDIR="$d/putty" SSH_AUTH_SOCK="$srv/agent.sock" ohne_tty "$p" -load s -batch -hostkey "$fp" "$@" \
    'echo AUSGABE-VOM-SERVER; read x; echo EINGABE-ZURUECK-$x' < <(printf 'GEHEIM-EINGABE\n') > "$d/$n.out" 2>&1
  echo "exit $?"; sed 's/^/  stdout: /' "$d/$n.out" | head -5
}
echo "== 1 ohne Protokoll"; lauf ohne
echo "== 2 -sessionlog (LGTYP_DEBUG laut cmdline.c)"; lauf debug -sessionlog "$d/debug.log"
ls -l "$d/debug.log" 2>&1 | awk '{print "  Datei:", $1, $5, "Bytes"}'; [ -f "$d/debug.log" ] && od -c "$d/debug.log" | head -8
echo "== 3 LogType=1 (ASCII) in der Sitzung"
printf 'LogType=1\nLogFileName=%s\n' "$d/ascii.log" >> "$d/putty/sessions/s"; lauf ascii
ls -l "$d/ascii.log" 2>&1 | awk '{print "  Datei:", $1, $5, "Bytes"}'; [ -f "$d/ascii.log" ] && od -c "$d/ascii.log" | head -8
echo "== 4 LogType=3 (SSH-Pakete) – enthält es die Eingabe?"
sed -i '' '/^LogType=/d;/^LogFileName=/d' "$d/putty/sessions/s"
printf 'LogType=3\nLogFileName=%s\n' "$d/pakete.log" >> "$d/putty/sessions/s"; lauf pakete
ls -l "$d/pakete.log" 2>&1 | awk '{print "  Datei:", $1, $5, "Bytes"}'
for w in AUSGABE-VOM-SERVER GEHEIM-EINGABE; do printf '  %s im Paketprotokoll: %s\n' "$w" "$(grep -c "$w" "$d/pakete.log" 2>/dev/null || echo 0)"; done
bash build/m1/testserver.sh stop >/dev/null 2>&1
rm -rf "$d"
