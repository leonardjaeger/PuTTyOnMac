#!/bin/bash
# M5: Was tut plink, wenn eine Sitzung sich selbst als SSH-Proxy nennt (importierte Datei)? Zeitlimit 15 s.
set -u
cache="$HOME/Library/Caches/TunnelTerminal-Build"; d="$cache/m5-schleife"; rm -rf "$d"; mkdir -p "$d/putty/sessions"; chmod -R 700 "$d"
printf 'HostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nProxyMethod=6\nProxyHost=schleife\nProxyLocalhost=1\n' > "$d/putty/sessions/schleife"
start=$(date +%s)
PUTTYDIR="$d/putty" perl -e 'use POSIX; POSIX::setsid(); alarm 15; exec @ARGV' "$cache/putty-0.85/bau/plink" -load schleife -batch exit </dev/null > "$d/out" 2>&1
echo "Exit $? nach $(( $(date +%s) - start )) s"; head -c 600 "$d/out" | tr '\r' ' ' | head -8; echo; wc -c < "$d/out"
rm -rf "$d"
