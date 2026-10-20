#!/bin/bash
# App-Tests (Bauwächter, Modus skript), optional nur einzelne Klassen: „apptest FileTransferTests WorkbenchTests“.
# Kurzprotokoll: Ergebnis je Test und Fehlermeldungen; Pfade mit ~ (S14).
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
only=(); for k in "$@"; do only+=("-only-testing:TunnelTerminalTests/$k"); done
xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj -scheme TunnelTerminal -destination 'platform=macOS' \
  -derivedDataPath "$cache/DerivedData" test "${only[@]}" > "$cache/m6-apptest.log" 2>&1
code=$?
grep -E "error:|failed|passed|Executed|TEST (SUCCEEDED|FAILED)" "$cache/m6-apptest.log" | grep -v -e "^\s*$" -e "linkd" | sed "s#$HOME#~#g" | tail -60
echo "exit=$code"
exit $code
