#!/bin/bash
# M0 Schritt 4: Prototyp bauen und als zwei Apps verpacken:
#   <Cache>/m0-out/Prototyp.app          – ohne Sandbox, Hardened Runtime
#   <Cache>/m0-out/Prototyp-Sandbox.app  – App Sandbox, plink mit app-sandbox + inherit
# Ausgabe NICHT im Projektordner: Der Schreibtisch liegt in iCloud Drive, der Dateianbieter setzt laufend
# com.apple.FinderInfo / com.apple.fileprovider.fpfs#P auf Pakete, und codesign bricht dann ab („detritus“).
# Beide ad hoc signiert (kein Entwickleraccount). plink kommt aus Schritt 3 (eigener Build, nie den Vergleichs-Build aus Quellen/).
set -euo pipefail
. build/m0/env.sh
P="build/m0/Prototyp"
plink="$PUTTY_BUILD/plink"
[ -x "$plink" ] || { echo "plink fehlt – zuerst 03-putty-bauen.sh"; exit 2; }

scratch="$HOME/Library/Caches/SSH-App-Build/m0-prototyp"
start=$(date +%s)
xcrun swift build -c release --package-path "$P" --scratch-path "$scratch" 2>&1 | tail -30
bin="$(xcrun swift build -c release --package-path "$P" --scratch-path "$scratch" --show-bin-path)/Prototyp"
echo "Bauzeit Prototyp: $(( $(date +%s) - start )) s"
echo "Bibliotheken des Prototyps:"; otool -L "$bin" | tail -n +2

out="$HOME/Library/Caches/SSH-App-Build/m0-out"
bundle() {
  local name="$1" sandbox="$2" app="$out/$1.app"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers"
  cp "$bin" "$app/Contents/MacOS/Prototyp"
  cp "$plink" "$app/Contents/Helpers/plink"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>de.leonardjaeger.sshapp.m0prototyp$( [ "$sandbox" = ja ] && echo .sandbox )</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleExecutable</key><string>Prototyp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
  xattr -cr "$app"   # codesign lehnt erweiterte Attribute (FinderInfo u. a.) im Paket ab
  if [ "$sandbox" = ja ]; then
    codesign -s - -f --options runtime --entitlements "$P/sandbox-helper.entitlements" "$app/Contents/Helpers/plink"
    codesign -s - -f --options runtime --entitlements "$P/sandbox-app.entitlements" "$app"
  else
    codesign -s - -f --options runtime "$app/Contents/Helpers/plink"
    codesign -s - -f --options runtime "$app"
  fi
  codesign --verify --deep --strict "$app" && echo "$name: Signatur ok"
  codesign -d --entitlements - "$app/Contents/Helpers/plink" 2>/dev/null | grep -o 'com.apple.security[a-z.-]*' | sort -u | sed 's/^/  plink: /' || echo "  plink: keine Entitlements"
}

rm -rf build/m0/out   # alte Pakete im iCloud-Ordner entfernen (nur build/), damit Launch Services nur die neuen kennt
mkdir -p "$out"
bundle Prototyp nein
bundle Prototyp-Sandbox ja
echo "Treffer /Users/ im Prototyp-Binary: $(strings "$out/Prototyp.app/Contents/MacOS/Prototyp" | grep -c '/Users/' || true)"
echo "Fertig. Pakete liegen im Cache-Ordner SSH-App-Build/m0-out"
