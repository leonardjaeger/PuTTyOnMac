#!/bin/bash
# Modi für den Bauwächter. Aufruf: bash Scripts/build.sh <modus>
#   build   – App bauen (Debug)
#   test    – alle Tests wie ⌘U (Kern über swift test, dann App)
#   kern    – nur die Kern-Tests (swift test, schnell)
#   skript  – build/skript.sh ausführen (Meilenstein-Hilfsskripte)
#   log     – Systemprotokoll der App der letzten 15 Minuten
set -u
cd "$(dirname "$0")/.." || exit 1
mode="${1:-}"
cache="$HOME/Library/Caches/SSH-App-Build"

case "$mode" in
  test)
    # Wie MintMarkPDF: xcodebuild führt die Kern-Tests (Swift Testing im lokalen Paket) auf der Kommandozeile
    # nicht aus, Xcode (⌘U) schon – hier deshalb zuerst swift test, dann die App-Tests.
    xcrun swift test --package-path SSHAppCore --scratch-path "$cache/CoreBuild" || exit $?
    xcodebuild -skipPackagePluginValidation -project SSHApp.xcodeproj -scheme SSHApp -destination 'platform=macOS' \
      -derivedDataPath "$cache/DerivedData" test
    ;;
  build)
    # SwiftTerm bringt ein Build-Plugin mit (erzeugt Versions- und terminfo-Tabellen, läuft in der
    # Xcode-Plugin-Sandbox ohne Netz; geprüft in M1). In Xcode einmal „Trust & Enable“ wählen.
    xcodebuild -skipPackagePluginValidation -project SSHApp.xcodeproj -scheme SSHApp -destination 'platform=macOS' \
      -derivedDataPath "$cache/DerivedData" "$mode"
    ;;
  kern)
    xcrun swift test --package-path SSHAppCore --scratch-path "$cache/CoreBuild"
    ;;
  skript)
    [ -f build/skript.sh ] || { echo "build/skript.sh fehlt."; exit 2; }
    bash build/skript.sh
    ;;
  log)
    log show --last 15m --info --style compact --predicate 'subsystem BEGINSWITH "de.leonardjaeger.sshapp"'
    ;;
  *)
    echo "Unbekannter Modus: '$mode' (erlaubt: build, test, kern, skript, log)"
    exit 64
    ;;
esac
