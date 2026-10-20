#!/bin/bash
# M5 (Prüfer-Befund): PortForwardings mit „\“ am Ende – liest plink über das Ende hinaus? (Absturz/Verhalten)
set -u
cache="$HOME/Library/Caches/TunnelTerminal-Build"; d="$cache/m5-bs"; rm -rf "$d"; mkdir -p "$d/putty/sessions"; chmod -R 700 "$d"
for v in 'L28095=a\' 'L28095=127.0.0.1:1,R1=x\' "L28095=$(printf 'A%.0s' {1..5000})\\"; do
  printf 'HostName=127.0.0.1\nPortNumber=1\nProtocol=ssh\nPortForwardings=%s\n' "$v" > "$d/putty/sessions/bs"
  PUTTYDIR="$d/putty" MallocScribble=1 MallocGuardEdges=1 perl -e 'use POSIX; POSIX::setsid(); alarm 10; exec @ARGV' \
    "$cache/putty-0.85/bau/plink" -v -load bs -batch exit </dev/null > "$d/out" 2>&1
  echo "Wert (${#v} Zeichen): Exit $?  $(grep -iE 'forward|refused|Unable' "$d/out" | head -2 | tr '\n' ' ' | cut -c1-160)"
done
rm -rf "$d"
