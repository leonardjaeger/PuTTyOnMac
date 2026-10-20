#!/bin/bash
# M1-Oberflächenprüfung: Wegwerf-SSH-Server nur für diesen Benutzer auf 127.0.0.1:2222 mit Wegwerf-Schlüssel
# im eigenen ssh-agent. ~/.ssh und das System-sshd bleiben unberührt. Aufruf: testserver.sh start|stop|status
# SFTP (M6): SFTP_START=<ordner> setzt den Startordner von sftp-server (leere Pfade landen dort statt im Home).
set -u
d="$HOME/Library/Caches/TunnelTerminal-Build/m1-testserver"
case "${1:-status}" in
  start)
    mkdir -p "$d"; chmod 700 "$d"
    [ -f "$d/host_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -C m1-host -f "$d/host_ed25519"
    [ -f "$d/client_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -C m1-client -f "$d/client_ed25519"
    cp "$d/client_ed25519.pub" "$d/authorized_keys"; chmod 600 "$d/authorized_keys"
    cat > "$d/sshd_config" <<CFG
Port 2222
ListenAddress 127.0.0.1
HostKey $d/host_ed25519
AuthorizedKeysFile $d/authorized_keys
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
StrictModes no
PidFile $d/sshd.pid
Subsystem sftp /usr/libexec/sftp-server${SFTP_START:+ -d $SFTP_START}
CFG
    /usr/sbin/sshd -t -f "$d/sshd_config" || exit 1
    nohup /usr/sbin/sshd -D -e -f "$d/sshd_config" > "$d/sshd.log" 2>&1 &
    echo $! > "$d/sshd.prozess"
    rm -f "$d/agent.sock"
    nohup ssh-agent -D -a "$d/agent.sock" > "$d/agent.log" 2>&1 &
    echo $! > "$d/agent.prozess"
    sleep 1
    SSH_AUTH_SOCK="$d/agent.sock" ssh-add "$d/client_ed25519"
    sleep 1; tail -3 "$d/sshd.log"
    echo "Agent-Socket: \$HOME/Library/Caches/TunnelTerminal-Build/m1-testserver/agent.sock"
    ;;
  stop)
    # Nur beenden, wenn die gespeicherte Nummer noch zu sshd bzw. ssh-agent gehört (Nummern werden wiederverwendet)
    for p in sshd agent; do
      [ -f "$d/$p.prozess" ] || continue
      pid="$(cat "$d/$p.prozess")"
      ps -p "$pid" -o comm= 2>/dev/null | grep -q "$( [ "$p" = agent ] && echo ssh-agent || echo sshd )" && kill "$pid"
    done
    sleep 1; rm -rf "$d"; echo "Testserver beendet und gelöscht."
    ;;
  status)
    for p in sshd agent; do [ -f "$d/$p.prozess" ] && ps -p "$(cat "$d/$p.prozess")" -o pid=,comm= ; done; true
    ;;
esac
