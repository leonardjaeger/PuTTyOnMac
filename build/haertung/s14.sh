#!/bin/bash
# Härtung S14: persönliche Daten in der fertigen App (DMG) und im Repo suchen. Aufruf über build/haertung/schritt.txt:
#   „s14 dmg [datei]“ – DMG schreibgeschützt einhängen, strings über ALLE Dateien, Treffer zählen und zeigen
#   „s14 repo“        – dieselben Muster über alle Repo-Dateien (git ls-files)
# Benutzer- und Rechnername nur zur Laufzeit (nie im Repo); Ausgabe maskiert. Erlaubt: Leonards Name als Autor
# (Copyright/Über) und die Bundle-ID „de.<benutzer>.tunnelterminal“.
set -u
cd "$(dirname "$0")/../.." || exit 1
benutzer=$(id -un)
rechner=$(scutil --get LocalHostName 2>/dev/null)
maske() { sed "s#$HOME#~#g; s#$benutzer#BENUTZER#g; s#$rechner#RECHNER#g"; }
erlaubt_ip='^(127\.|0\.0\.0\.0$|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|255\.)'
pruefe() {   # $1 = Datei mit Zeilen „pfad: text“
  local t="$1"
  echo "Zeilen gesamt: $(wc -l < "$t")"
  echo "--- /Users/: $(grep -c '/Users/' "$t")"; grep '/Users/' "$t" | maske | head -10
  echo "--- Benutzername außerhalb der Bundle-ID: $(grep -i "$benutzer" "$t" | grep -vic "de\.$benutzer\.tunnelterminal")"
  grep -i "$benutzer" "$t" | grep -vi "de\.$benutzer\.tunnelterminal" | maske | head -10
  echo "--- Rechnername: $(grep -ic "$rechner" "$t")"; grep -i "$rechner" "$t" | maske | head -5
  echo "--- IPv4 außerhalb Loopback/Dokumentationsbereich (eindeutig):"
  grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$t" | sed -E 's/^[^:]*://' | grep -vE "$erlaubt_ip" | sort | uniq -c | head -20
  echo "--- private Netze (10/8, 172.16/12, 192.168/16): $(grep -cE '\b(10\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9]{1,3}\.[0-9]{1,3}\b' "$t")"
  echo "--- E-Mail-Adressen (eindeutig, ohne *.example/*.test/noreply):"
  grep -oiE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$t" | grep -viE '@([a-z0-9.-]*\.)?(example|test|invalid)$|noreply|@[0-9]+x\.png$|@(openssh\.com|libssh\.org|ssh\.com|lysator\.liu\.se|tartarus\.org)$' | sort | uniq -c | maske | head -20
  echo "--- Nachname (erlaubt nur als Autor):"; grep -iE 'J(ä|ae|a)ger|J.{1,2}ger ' "$t" | grep -vi "de\.$benutzer\." | cut -c1-160 | sort -u | maske | head -10
}
case "${1:-}" in
  dmg)
    dmg="${2:-$(ls build/Weitergabe/TunnelTerminal-*.dmg | tail -1)}"
    mnt=$(mktemp -d /tmp/tt-s14.XXXXXX)
    hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg" >/dev/null || exit 1
    echo "DMG: $dmg · SHA-256 $(shasum -a 256 "$dmg" | cut -c1-16)…"
    echo "Dateien im DMG: $(find "$mnt" -type f | wc -l | tr -d ' ')"
    t=$(mktemp /tmp/tt-s14-text.XXXXXX)
    find "$mnt" -type f -print0 | while IFS= read -r -d '' f; do
      LC_ALL=C strings -a -n 4 "$f" 2>/dev/null | sed "s#^#${f#$mnt/}: #"
    done > "$t"
    # Erweiterte Attribute (z. B. Quarantäne, Herkunft) der Dateien im DMG
    echo "--- erweiterte Attribute: $(find "$mnt" -exec xattr {} + 2>/dev/null | cut -d: -f2 | sort | uniq -c | tr '\n' ' ')"
    pruefe "$t"
    hdiutil detach "$mnt" -quiet; rmdir "$mnt" 2>/dev/null; rm -f "$t"
    ;;
  repo)
    t=$(mktemp /tmp/tt-s14-text.XXXXXX)
    git ls-files -z | while IFS= read -r -d '' f; do LC_ALL=C strings -a -n 4 "$f" 2>/dev/null | sed "s#^#$f: #"; done > "$t"
    echo "Repo-Dateien: $(git ls-files | wc -l | tr -d ' ')"
    pruefe "$t"; rm -f "$t"
    ;;
  *) echo "Aufruf: s14.sh dmg [datei] | repo"; exit 64 ;;
esac
