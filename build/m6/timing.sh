#!/bin/bash
# Bau-Zeiten M6 (RL 3.1 Regel 4): sauberer Bau in eigenem DerivedData mit Warnungen für langsame Funktionen/Ausdrücke
# (>100 ms), danach Bau nach Änderung einer Datei. Ausgabe ohne Pfade mit Benutzernamen.
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
dd="$cache/m6-timing"; rm -rf "$dd"
flags='-Xfrontend -warn-long-function-bodies=100 -Xfrontend -warn-long-expression-type-checking=100'
bau() { xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj -scheme TunnelTerminal -destination 'platform=macOS' \
  -derivedDataPath "$dd" OTHER_SWIFT_FLAGS="$flags" build > "$cache/m6-timing.log" 2>&1; }
s=$(date +%s); bau; e=$(date +%s); echo "sauber: $((e - s)) s, $(tail -1 "$cache/m6-timing.log")"
grep -E "warning: (instance method|global function|getter|initializer|closure|expression|static method).*took" "$cache/m6-timing.log" \
  | grep -v SourcePackages | sed "s#$HOME#~#g" | sort -u | head -20
touch TunnelTerminal/FileTransferController.swift
s=$(date +%s); bau; e=$(date +%s); echo "nach Änderung FileTransferController.swift: $((e - s)) s, $(tail -1 "$cache/m6-timing.log")"
rm -rf "$dd"
