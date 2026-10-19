#!/bin/bash
# M3-Machbarkeit (Bauwächter, Modus skript): puttygen-Aufrufe, Passphrasen über Pipes, Hostschlüssel-Format.
# Nur Wegwerf-Schlüssel in einem Cache-Ordner; ~/.ssh, der Schlüsselbund und das System-sshd bleiben unberührt.
# Der Benutzername wird nur zur Laufzeit geholt und nie ausgegeben (S14).
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
bau="$cache/putty-0.85/bau"
g="$bau/puttygen"; p="$bau/plink"
d="$cache/m3-machbarkeit"; rm -rf "$d"; mkdir -p "$d/putty/sessions"; chmod -R 700 "$d"
# ohne Steuerterminal wie in der App (sonst fragte puttygen im Fenster des Bauwächters)
ohne_tty() { perl -e 'use POSIX; POSIX::setsid(); alarm 20; exec @ARGV or exit 127' "$@"; }
pub() { ohne_tty "$g" "$1" -L </dev/null; }

echo "== 0 Versionen und GSSAPI"
"$p" -V | head -3; "$g" -V | head -1
for t in plink puttygen; do printf '%s: libgssapi-Treffer %s\n' "$t" "$(strings "$bau/$t" | grep -c libgssapi)"; done

echo "== 1 Erzeugen Ed25519, Passphrase über fd 3"
ohne_tty "$g" -t ed25519 -C test-schluessel -q -o "$d/a.ppk" --new-passphrase /dev/fd/3 3< <(printf 'geheim\n') </dev/null; echo "exit $?"
stat -f '%Lp %z %N' "$d/a.ppk" | sed "s#$d/##"; head -3 "$d/a.ppk"

echo "== 2 Öffentlicher Teil und Fingerabdruck ohne Passphrase"
pub "$d/a.ppk"; echo "exit $?"
ohne_tty "$g" "$d/a.ppk" -l </dev/null; echo "exit $?"
ohne_tty "$g" "$d/a.ppk" -l -E md5 </dev/null; echo "exit $?"

echo "== 3 Privat nach OpenSSH ohne Passphrase-Datei (darf nicht hängen)"
ohne_tty "$g" "$d/a.ppk" -O private-openssh -o "$d/x_openssh" </dev/null; echo "exit $?"; ls "$d/x_openssh" 2>&1 | sed "s#$d/##"

echo "== 4 Privat nach OpenSSH mit Passphrase"
ohne_tty "$g" "$d/a.ppk" -O private-openssh -o "$d/a_openssh" --old-passphrase /dev/fd/3 3< <(printf 'geheim\n') </dev/null; echo "exit $?"
stat -f '%Lp %N' "$d/a_openssh" | sed "s#$d/##"; head -1 "$d/a_openssh"
echo "ssh-keygen liest: $(ssh-keygen -y -P geheim -f "$d/a_openssh")"
ssh-keygen -y -P geheim -f "$d/a_openssh" > "$d/a_openssh.pub"; ssh-keygen -lf "$d/a_openssh.pub"

echo "== 5 Falsche Passphrase"
ohne_tty "$g" "$d/a.ppk" -O private-openssh -o "$d/f_openssh" --old-passphrase /dev/fd/3 3< <(printf 'falsch\n') </dev/null; echo "exit $?"

echo "== 6 OpenSSH (ssh-keygen, verschlüsselt) nach .ppk"
ssh-keygen -q -t ed25519 -N geheim -C test-openssh -f "$d/o"
pub "$d/o"; echo "exit -L ohne Passphrase: $?"
ohne_tty "$g" "$d/o" -o "$d/o.ppk" --old-passphrase /dev/fd/3 3< <(printf 'geheim\n') </dev/null; echo "exit $?"
head -3 "$d/o.ppk"; stat -f '%Lp %N' "$d/o.ppk" | sed "s#$d/##"
echo "gleich: $( [ "$(pub "$d/o.ppk" | cut -d' ' -f1-2)" = "$(cut -d' ' -f1-2 "$d/o.pub")" ] && echo ja || echo nein)"

echo "== 7 Passphrase entfernen (-P, neue leer)"
ohne_tty "$g" "$d/a.ppk" -P -o "$d/c.ppk" --old-passphrase /dev/fd/3 --new-passphrase /dev/fd/4 3< <(printf 'geheim\n') 4< <(printf '') </dev/null; echo "exit $?"
sed -n 2p "$d/c.ppk"

echo "== 8 Andere Typen (Zeit)"
for t in "ecdsa -b 256" "rsa -b 4096"; do
  s=$(date +%s); ohne_tty "$g" -t $t -q -o "$d/t.ppk" --new-passphrase /dev/fd/3 3< <(printf '') </dev/null; echo "$t: exit $? in $(( $(date +%s) - s )) s"; sed -n 1,2p "$d/t.ppk"
done
echo "Datei vorhanden, ohne -o überschreiben?"; ohne_tty "$g" -t ed25519 -q -o "$d/a.ppk" --new-passphrase /dev/fd/3 3< <(printf '') </dev/null; echo "exit $?"

echo "== 9 Hostschlüssel-Format (eigener sshd auf 127.0.0.1:2223 mit vier Schlüsseltypen)"
for t in ed25519 ecdsa rsa; do ssh-keygen -q -t $t -N '' -C m3-host -f "$d/host_$t"; done
# je Typ ein eigener sshd mit nur diesem Hostschlüssel und ein eigener PuTTY-Ordner
for alg in ed25519 ecdsa rsa; do
  cat > "$d/sshd_$alg" <<CFG
Port 2223
ListenAddress 127.0.0.1
HostKey $d/host_$alg
AuthorizedKeysFile none
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
StrictModes no
PidFile $d/sshd.pid
CFG
  /usr/sbin/sshd -D -e -f "$d/sshd_$alg" > "$d/sshd_$alg.log" 2>&1 &
  sshd_pid=$!; sleep 1
  mkdir -p "$d/putty-$alg/sessions"
  printf 'HostName=127.0.0.1\nPortNumber=2223\nProtocol=ssh\nSshNoShell=1\n' > "$d/putty-$alg/sessions/hk"
  PUTTYDIR="$d/putty-$alg" expect -c "
    set timeout 15
    spawn $p -load hk -l [exec id -un] -no-antispoof
    expect {
      -re {fingerprint is:\s*\r?\n\s*(\S+ \S+ \S+)} { puts \"\nplink zeigt: \$expect_out(1,string)\"; exp_continue }
      {(y/n} { send \"y\r\"; exp_continue }
      eof {}
      timeout { puts zeitueberschreitung }
    }" 2>&1 | grep -E 'plink zeigt|zeitueberschreitung'
  kill "$sshd_pid" 2>/dev/null; wait "$sshd_pid" 2>/dev/null
done
echo "-- sshhostkeys (Wegwerf-Schlüssel, nur 127.0.0.1):"; for alg in ed25519 ecdsa rsa; do cat "$d/putty-$alg/sshhostkeys"; done
echo "-- ssh-keygen dazu:"; for t in ed25519 ecdsa rsa; do ssh-keygen -lf "$d/host_$t.pub"; ssh-keygen -E md5 -lf "$d/host_$t.pub"; cat "$d/host_$t.pub"; done
echo "== fertig"
