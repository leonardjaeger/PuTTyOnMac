#!/bin/bash
# M6-Machbarkeit (Bauwächter, Modus skript): pscp ohne Terminal wie in der App (probe.py), gegen den Wegwerf-sshd aus
# M1 (127.0.0.1:2222, nur Schlüssel über eigenen Agenten). Eigener PuTTY-Ordner im Cache; Benutzername nur zur Laufzeit,
# nie im Log (S14, Pfade mit ~ maskiert). Hostschlüssel nur hier im Testskript fest vorgegeben (SSHManualHostKeys).
# Aufruf über schritt.txt: „machbarkeit alles“
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
s="${PSCP:-$cache/putty-0.85/bau/pscp}"
srv="$cache/m1-testserver"
d="$cache/m6-machbarkeit"; rm -rf "$d"; mkdir -p "$d/putty/sessions" "$d/lokal" "$d/fern/ziel"; chmod -R 700 "$d"
maske() { sed "s#$HOME#~#g; s#$(id -un)#BENUTZER#g"; }
probe() { python3 build/m6/probe.py "$@" | maske; }
"$s" -V | head -1
bash build/m1/testserver.sh start >/dev/null 2>&1
fp=$(ssh-keygen -lf "$srv/host_ed25519.pub" -E sha256 | cut -d' ' -f2)
basis() { printf 'HostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\nSSHManualHostKeys=%s\n%b' "$(id -un)" "$fp" "${1:-}"; }
export PUTTYDIR="$d/putty" SSH_AUTH_SOCK="$srv/agent.sock"
basis > "$d/putty/sessions/m6"
o="-load m6 -sftp -batch"
echo "kleine Datei" > "$d/lokal/klein.txt"
dd if=/dev/urandom of="$d/lokal/gross.bin" bs=1048576 count=400 2>/dev/null
F="$d/fern"

echo "== 1 Hochladen klein in Ordner (127.0.0.1:<abs>)"
probe 0 "$d/r1" "$s" $o "$d/lokal/klein.txt" "127.0.0.1:$F/ziel"; ls -l "$F/ziel" | maske | tail -n +2
echo "== 2 Hochladen groß (400 MB), Fortschritt"
probe 0 "$d/r2" "$s" $o "$d/lokal/gross.bin" "127.0.0.1:$F/ziel"; sed -n '1,4p;$p' "$d/r2" | cut -c1-160 | maske
echo "== 3 Hochladen groß, nach 1,5 s SIGHUP"
rm -f "$F/ziel/gross.bin"
probe 1.5 "$d/r3" "$s" $o "$d/lokal/gross.bin" "127.0.0.1:$F/ziel"; ls -l "$F/ziel/gross.bin" 2>&1 | maske
echo "== 4 Ordner auflisten (-ls), dann nicht vorhandenen Ordner"
probe 0 "$d/r4" "$s" $o -q -ls "127.0.0.1:$F/ziel"
probe 0 "$d/r4b" "$s" $o -q -ls "127.0.0.1:$F/fehlt"
echo "== 4c -ls mit leerem Pfad (Home) – nur Zeilenzahl"
probe 0 "$d/r4c" "$s" $o -q -ls "127.0.0.1:" | head -1
echo "== 5 Herunterladen in eine Datei mit eigenem Namen; Rechte"
probe 0 "$d/r5" "$s" $o "127.0.0.1:$F/ziel/klein.txt" "$d/lokal/geladen.tmp"; ls -l "$d/lokal/geladen.tmp" | cut -c1-11
echo "== 6 Herunterladen: fehlt / Ordner / Wildcard-Zeichen escaped"
probe 0 "$d/r6" "$s" $o "127.0.0.1:$F/ziel/fehlt.txt" "$d/lokal/x"
probe 0 "$d/r6b" "$s" $o "127.0.0.1:$F/ziel" "$d/lokal/y"
echo stern > "$F/ziel/a*b?[c].txt"; echo falsch > "$F/ziel/aXbY[c].txt"; echo zz > "$F/ziel/acbd.txt"
probe 0 "$d/r6c" "$s" $o "127.0.0.1:$F/ziel/a\\*b\\?\\[c\\].txt" "$d/lokal/stern.tmp"; echo "  Inhalt: $(cat "$d/lokal/stern.tmp" 2>&1 | maske)"
probe 0 "$d/r6d" "$s" $o "127.0.0.1:$F/ziel/a*b?[c].txt" "$d/lokal/stern2.tmp"; echo "  ohne Escape, Inhalt: $(cat "$d/lokal/stern2.tmp" 2>&1 | maske)"
echo "== 7 Herunterladen groß mit SIGHUP nach 1 s"
probe 1 "$d/r7" "$s" $o "127.0.0.1:$F/ziel/gross.bin" "$d/lokal/gross.tmp"; ls -l "$d/lokal/gross.tmp" 2>&1 | maske | cut -c1-80
echo "== 8 Zielordner leer (Home) und mit ~/"
n="m6-probe-$$-$RANDOM.txt"; cp "$d/lokal/klein.txt" "$d/lokal/$n"
[ -e "$HOME/$n" ] && { echo "  $n gibt es schon – übersprungen"; } || {
  probe 0 "$d/r8" "$s" $o "$d/lokal/$n" "127.0.0.1:"; ls "$HOME/$n" 2>&1 | maske; rm -f "$HOME/$n"; }
mkdir -p "$d/fern/tilde"
probe 0 "$d/r8b" "$s" $o "$d/lokal/klein.txt" "127.0.0.1:~/Library/Caches/TunnelTerminal-Build/m6-machbarkeit/fern/tilde"; ls "$d/fern/tilde" 2>&1
echo "== 9 „--“ (überspringt pscp 0.85 das Argument danach?) und Backslash im Namen"
cp "$d/lokal/klein.txt" "$d/lokal/nach-strichen.txt"; cp "$d/lokal/klein.txt" "$d/lokal/a\\b.txt"
probe 0 "$d/r9" "$s" $o -- /gibt/es/nicht "$d/lokal/nach-strichen.txt" "127.0.0.1:$F/ziel"
probe 0 "$d/r9b" "$s" $o "$d/lokal/a\\b.txt" "127.0.0.1:$F/ziel"; ls "$F/ziel" | maske
echo "== 10 Einzelne Datei an nicht vorhandenen Ordner (legt Datei an?)"
probe 0 "$d/r10" "$s" $o "$d/lokal/klein.txt" "127.0.0.1:$F/neu"; ls -l "$F" | maske | tail -n +2
echo "== 11 Hostschlüssel unbekannt (ohne SSHManualHostKeys, leeres sshhostkeys)"
printf 'HostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=%s\n' "$(id -un)" > "$d/putty/sessions/unbekannt"
probe 0 "$d/r11" "$s" -load unbekannt -sftp -batch "$d/lokal/klein.txt" "127.0.0.1:$F/ziel"
echo "== 12 Benutzer leer: was nimmt pscp? (Verbose-Zeile)"
printf 'HostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nSSHManualHostKeys=%s\n' "$fp" > "$d/putty/sessions/ohne-benutzer"
probe 0 "$d/r12" "$s" -v -load ohne-benutzer -sftp -batch -q -ls "127.0.0.1:$F/ziel" | grep -iE "user|exit" | head -3
echo "== 13 Passwort nötig: System-sshd :22 (Entfernte Anmeldung), ohne Agent und Schlüssel"
if nc -z 127.0.0.1 22 2>/dev/null; then
  hk=$(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256 | cut -d' ' -f2)
  printf 'HostName=127.0.0.1\nPortNumber=22\nProtocol=ssh\nUserName=%s\nTryAgent=0\nSSHManualHostKeys=%s\n' "$(id -un)" "$hk" > "$d/putty/sessions/pw"
  probe 0 "$d/r13" "$s" -load pw -sftp -batch -q -ls "127.0.0.1:/tmp"
else echo "  Port 22 zu (Entfernte Anmeldung aus) – nicht gemessen"; fi
echo "== 14 Jump-Host-Sitzung (ProxyMethod=6)"
basis 'ProxyMethod=6\nProxyHost=m6\nProxyLocalhost=1\n' > "$d/putty/sessions/sprung"
probe 0 "$d/r14" "$s" -load sprung -sftp -batch "$d/lokal/klein.txt" "127.0.0.1:$F/ziel/ueber-sprung.txt"; ls "$F/ziel" | grep sprung
echo "== 15 Dauer einer Anmeldung (-ls, 3 Läufe)"
for i in 1 2 3; do /usr/bin/time -p "$s" $o -q -ls "127.0.0.1:$F/ziel" 2>&1 >/dev/null </dev/null | grep real; done
echo "== 16 Datei mit Leerzeichen, Umlaut, Steuerzeichen-Name auf dem Server: -ls zeigt?"
touch "$F/ziel/mit leer zeichen.txt" "$F/ziel/Ümlaut.txt" "$F/ziel/$(printf 'esc\033[31mrot')"
probe 0 "$d/r16" "$s" $o -q -ls "127.0.0.1:$F/ziel" | grep -E "leer|mlaut|esc" ; grep -a "esc" "$d/r16" | cut -c1-120 | maske
echo "== 17 Hochladen auf vorhandene Datei: überschreibt? (Inhalt vorher/nachher)"
echo "alt" > "$F/ziel/klein.txt"; probe 0 "$d/r17" "$s" $o "$d/lokal/klein.txt" "127.0.0.1:$F/ziel"; echo "  nachher: $(cat "$F/ziel/klein.txt")"
echo "== 18 Zielordner ohne Schreibrecht"
mkdir -p "$F/nurlesen"; chmod 500 "$F/nurlesen"
probe 0 "$d/r18" "$s" $o "$d/lokal/klein.txt" "127.0.0.1:$F/nurlesen"; chmod 700 "$F/nurlesen"
bash build/m1/testserver.sh stop >/dev/null 2>&1
mkdir -p "$cache/m6-aufz"; cp "$d"/r* "$cache/m6-aufz/" 2>/dev/null
rm -rf "$d"
