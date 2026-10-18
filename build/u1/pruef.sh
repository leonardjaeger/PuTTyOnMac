#!/bin/bash
# U1 Release-Prüfung: Release-Bau in eigenem Cache-Ordner, dann Kennung, Version, Signatur, Hardened Runtime, Entitlements, Pfade (S14).
set -u
dd="$HOME/Library/Caches/TunnelTerminal-Build/ReleaseCheck"
xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj -scheme TunnelTerminal -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$dd" build > "$dd.log" 2>&1; echo "xcodebuild Exit $?"
grep -E '(^|[^A-Za-z])(error|warning): ' "$dd.log" | grep -v appintents | sed "s#$HOME#~#g" | sort -u | head -20
app="$dd/Build/Products/Release/TunnelTerminal.app"; plist="$app/Contents/Info.plist"
echo "Bundle-ID: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist") · Version $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist") ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist"))"
echo "App: $(codesign -dv "$app" 2>&1 | grep -oE 'Identifier=[^ ]+|flags=[^ ]+' | tr '\n' ' ')"
for h in "$app"/Contents/Helpers/*; do echo "$(basename "$h"): $(codesign -dv "$h" 2>&1 | grep -oE 'flags=[^ ]+')"; done
codesign --verify --deep --strict "$app" && echo "codesign --verify: ok"
echo "Entitlements:"; codesign -d --entitlements :- "$app" 2>/dev/null | grep -oE '<key>[^<]+' | sed 's/<key>//'
echo "Dateien mit /Users/ im Release-Paket: $(LC_ALL=C grep -rlaF '/Users/' "$app" | sed "s#$app/##" | tr '\n' ' ')"
