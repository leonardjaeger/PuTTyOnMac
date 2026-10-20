#!/bin/bash
# Kurzanleitung (Hilfe-Menü, Plan M7): Quelle ist Scripts/hilfe/Kurzanleitung.html, die App liest die daraus erzeugte
# RTF-Datei. Der HTML-Import braucht WebKit auf dem Hauptthread (≈ 0,2 s beim ersten Öffnen, Richtlinien 3.7), RTF nicht.
#   bash Scripts/kurzanleitung.sh           – TunnelTerminal/Kurzanleitung.rtf neu erzeugen (nach jeder Änderung am HTML)
#   bash Scripts/kurzanleitung.sh --pruefen – nur prüfen, ob die RTF-Datei zur Quelle passt (make-dmg.sh vor dem Bau)
set -u
cd "$(dirname "$0")/.." || exit 1
ziel="TunnelTerminal/Kurzanleitung.rtf"
if [ "${1:-}" = "--pruefen" ]; then
  neu="$(mktemp -t kurzanleitung)"
  textutil -convert rtf -inputencoding UTF-8 -output "$neu" Scripts/hilfe/Kurzanleitung.html || exit 1
  if cmp -s "$neu" "$ziel"; then rm -f "$neu"; echo "  Kurzanleitung.rtf passt zur Quelle"
  else rm -f "$neu"; echo "✗ Kurzanleitung.rtf veraltet: bash Scripts/kurzanleitung.sh"; exit 1; fi
else
  textutil -convert rtf -inputencoding UTF-8 -output "$ziel" Scripts/hilfe/Kurzanleitung.html || exit 1
  echo "$ziel erzeugt ($(wc -c < "$ziel" | tr -d ' ') Bytes)"
fi
