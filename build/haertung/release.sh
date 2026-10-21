#!/bin/bash
# Härtung: Weitergabe-Prüfung (release-review) am fertigen DMG. Aufruf über build/haertung/schritt.txt: „release [dmg]“
# Liest nur; Ausgabe maskiert (S14).
set -u
cd "$(dirname "$0")/../.." || exit 1
maske() { sed "s#$HOME#~#g; s#$(id -un)#BENUTZER#g"; }
dmg="${1:-$(ls build/Weitergabe/TunnelTerminal-*.dmg | tail -1)}"
mnt=$(mktemp -d /tmp/tt-rel.XXXXXX)
hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg" >/dev/null || exit 1
app="$mnt/TunnelTerminal.app"
echo "--- DMG-Inhalt"; ls -la "$mnt" | sed 1d | awk '{print $1, $NF, ($11 ? $10" "$11 : "")}'
echo "--- DMG-Signatur/Format"; hdiutil imageinfo "$dmg" 2>/dev/null | grep -E '^Format:|Format Description|Checksum Type' | head -3
codesign -dv "$dmg" 2>&1 | head -2 | maske
echo "--- App: Signatur"
codesign --verify --deep --strict --verbose=2 "$app" 2>&1 | tail -2 | maske
codesign -dvvv "$app" 2>&1 | grep -E 'Identifier|Format|CodeDirectory|Signature|TeamIdentifier|Runtime|flags' | maske
echo "--- App: Entitlements"; codesign -d --entitlements - --xml "$app" 2>/dev/null | plutil -p - 2>/dev/null || echo "(keine)"
for h in "$app"/Contents/Helpers/*; do
  n=$(basename "$h")
  flags=$(codesign -dv "$h" 2>&1 | grep -oE 'flags=0x[0-9a-f]+\([a-z,-]+\)')
  ent=$(codesign -d --entitlements - --xml "$h" 2>/dev/null | plutil -p - 2>/dev/null | tr -d '\n' )
  libs=$(otool -L "$h" | sed 1d | awk '{print $1}' | tr '\n' ' ')
  echo "Helper $n: $flags · Entitlements: ${ent:-keine} · Bibliotheken: $libs"
done
echo "--- App: Bibliotheken außerhalb des Systems"
otool -L "$app/Contents/MacOS/TunnelTerminal" | sed 1d | awk '{print $1}' | grep -vE '^/(System|usr/lib)/' || echo "(keine)"
otool -l "$app/Contents/MacOS/TunnelTerminal" | grep -A2 LC_RPATH | grep path | maske
echo "--- Info.plist"
plutil -p "$app/Contents/Info.plist" | grep -E 'CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion|LSMinimumSystemVersion|NSHumanReadableCopyright|CFBundleURLSchemes|"ssh"|"telnet"|NSLocalNetworkUsageDescription|LSApplicationCategoryType|NSAppTransportSecurity|NSAllowsArbitraryLoads|OSLogPreferences|CFBundleIconName|CFBundleIconFile' | maske
echo "--- Mitgelieferte Lizenzen"; ls "$app/Contents/Resources" | grep -iE 'licen|notice|lizenz|THIRD' || echo "(keine Dateien mit Lizenz im Namen)"
echo "--- Gatekeeper (ohne Entwickler-ID erwartet: abgelehnt)"; spctl -a -vv -t execute "$app" 2>&1 | maske | head -3
echo "--- Quarantäne-Simulation: xattr der App"; xattr -l "$app" 2>/dev/null | head -3; echo "(Ende)"
echo "--- Datenschutz: Netzwerk-/Analytics-Frameworks"
otool -L "$app/Contents/MacOS/TunnelTerminal" | grep -iE 'Network|Analytics|Crash|Sentry|Firebase' | awk '{print $1}' || true
echo "--- Größe"; du -sh "$app" | maske; ls -la "$dmg" | awk '{print $5}'
hdiutil detach "$mnt" -quiet; rmdir "$mnt" 2>/dev/null
