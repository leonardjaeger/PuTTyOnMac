#!/bin/bash
# Modi für den Bauwächter. Aufruf: bash Scripts/build.sh <modus>
#   build   – Xcode-Projekt bauen (ab M1)
#   test    – Xcode-Tests (ab M1)
#   skript  – build/skript.sh ausführen (Meilenstein-Hilfsskripte, Ausgabe im Log)
#   log     – Systemprotokoll der App/des Prototyps der letzten 15 Minuten
set -u
cd "$(dirname "$0")/.." || exit 1
mode="${1:-}"

xcodeproj() {
  ls -d ./*.xcodeproj 2>/dev/null | head -1
}

case "$mode" in
  build|test)
    proj=$(xcodeproj)
    if [ -z "$proj" ]; then
      echo "Noch kein Xcode-Projekt vorhanden (entsteht in M1)."
      exit 3
    fi
    scheme=$(basename "$proj" .xcodeproj)
    xcodebuild -project "$proj" -scheme "$scheme" -destination 'platform=macOS' \
      -derivedDataPath "$HOME/Library/Caches/SSH-App-Build/DerivedData" "$mode"
    ;;
  skript)
    if [ ! -f build/skript.sh ]; then
      echo "build/skript.sh fehlt."
      exit 2
    fi
    bash build/skript.sh
    ;;
  log)
    log show --last 15m --info --style compact \
      --predicate 'subsystem BEGINSWITH "de.leonardjaeger.sshapp" OR process == "Prototyp"'
    ;;
  *)
    echo "Unbekannter Modus: '$mode' (erlaubt: build, test, skript, log)"
    exit 64
    ;;
esac
