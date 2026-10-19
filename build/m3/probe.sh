#!/bin/bash
# Einmalige Messung: Welchen Port nimmt plink bei einer Sitzung ohne bzw. mit Protocol?
set -u
cache="$HOME/Library/Caches/TunnelTerminal-Build"; p="$cache/putty-0.85/bau/plink"
d="$cache/m3-probe"; rm -rf "$d"; mkdir -p "$d/sessions"
printf 'HostName=127.0.0.1\nPortNumber=1\nUserName=test\n' > "$d/sessions/ohne"
printf 'HostName=127.0.0.1\nPortNumber=1\nUserName=test\nProtocol=ssh\n' > "$d/sessions/mit"
for s in ohne mit; do echo "== $s"; PUTTYDIR="$d" perl -e 'use POSIX; POSIX::setsid(); alarm 8; exec @ARGV' "$p" -load $s -batch -v </dev/null 2>&1 | grep -i "connect\|port\|refused\|host key" | head -4; done
rm -rf "$d"
