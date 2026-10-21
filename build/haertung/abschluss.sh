#!/bin/bash
# Härtung: Abschluss nach der Abnahme (Bauwächter, Modus skript): „abschluss <schritt>“ in build/haertung/schritt.txt.
#   anleitung – Kurzanleitung.rtf aus der HTML-Quelle neu erzeugen und prüfen
#   dmg       – fertige DMG prüfen: S14-Suche, Weitergabe-Prüfung, Kurzanleitung im Paket = Quelle
#   rest      – prüft nach „ui stop“, dass von der Testumgebung nichts übrig ist (liest nur)
#   los       – Commit (Nachricht aus build/haertung/commit.txt, nicht im Repo) und Tag v1.0
#   push      – main und Tag v1.0 nach origin
# Keine Rückfragen am Terminal.
set -u
cd "$(dirname "$0")/../.." || exit 1
export GIT_TERMINAL_PROMPT=0
case "${1:-}" in
  anleitung)
    bash Scripts/kurzanleitung.sh && bash Scripts/kurzanleitung.sh --pruefen
    ;;
  dmg)
    d=build/Weitergabe/TunnelTerminal-1.0.0.dmg
    bash build/haertung/s14.sh dmg "$d"; bash build/haertung/release.sh "$d"
    m=$(mktemp -d /tmp/tt-kz.XXXXXX)
    hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$m" "$d" >/dev/null || exit 1
    if cmp -s "$m/TunnelTerminal.app/Contents/Resources/Kurzanleitung.rtf" TunnelTerminal/Kurzanleitung.rtf
    then echo "  Kurzanleitung im Paket = Quelle"; else echo "✗ Kurzanleitung im Paket veraltet"; fi
    hdiutil detach -quiet "$m"
    ;;
  rest)
    putty="$HOME/Library/Application Support/TunnelTerminal/putty"; cache="$HOME/Library/Caches/TunnelTerminal-Build"
    echo "Sitzungen „Härtung/…“: $(ls "$putty/sessions" | grep -c '^H%C3%A4rtung')"
    echo "Protokolle „Härtung-…“: $(ls "$HOME/Library/Logs/TunnelTerminal" 2>/dev/null | grep -c 'rtung')"
    echo "Hostschlüssel 127.0.0.1:2222: $(grep -c '@2222:127\.0\.0\.1 ' "$putty/sshhostkeys" 2>/dev/null)"
    echo "Schlüsselbund-Eintrag: $(security find-generic-password -a "Härtung/Passwort" >/dev/null 2>&1 && echo da || echo weg)"
    echo "Ordner haertung-ui/ReleaseProfil: $(ls -d "$cache/haertung-ui" "$cache/ReleaseProfil" 2>/dev/null | wc -l | tr -d ' ')"
    echo "TunnelTerminal/plink laufen:"; for pid in $(pgrep -f 'TunnelTerminal.app/Contents/(MacOS|Helpers)/'); do ps -o pid=,ppid=,stat=,%cpu=,etime=,command= -p "$pid"; lsof -nP -a -p "$pid" -i 2>/dev/null | awk 'NR>1 {sub(/.*->/, "", $9); sub(/.*:/, "Port ", $9); print "    ", $8, $9, $10}'; done | sed "s#$HOME#~#g; s#$(id -un)#BENUTZER#g"
    echo "Port 2222 offen: $(lsof -nP -iTCP:2222 -sTCP:LISTEN 2>/dev/null | sed 1d | wc -l | tr -d ' ')"
    ;;
  los)
    [ -s build/haertung/commit.txt ] || { echo "build/haertung/commit.txt fehlt"; exit 64; }
    git rev-parse -q --verify refs/tags/v1.0 >/dev/null && { echo "Tag v1.0 gibt es schon"; exit 65; }
    git add -A && git commit -q -F build/haertung/commit.txt && git tag v1.0 || exit 1
    git log --oneline -1; git tag --points-at HEAD; git status --short | head -5; echo "commit exit 0"
    ;;
  push)
    git status -sb | head -1
    git push origin main 2>&1 && git push origin v1.0 2>&1
    echo "push exit $?"
    git status -sb | head -1
    ;;
  *) echo "Aufruf: abschluss.sh anleitung|dmg|rest|los|push"; exit 64 ;;
esac
