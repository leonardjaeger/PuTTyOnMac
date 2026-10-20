#!/bin/bash
# Weitergabe-DMG (Plan M7): Release-Bau in eigenem Cache-Ordner, Prüfungen, DMG mit „Zuerst lesen“ und Verweis auf
# /Programme, SHA-256 daneben. Aufruf über den Bauwächter: bash Scripts/build.sh dmg
# Ohne gültige Signatur, mit get-task-allow oder mit Pfaden/Benutzernamen im Paket entsteht keine DMG (S8, S14).
set -u
cd "$(dirname "$0")/.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
derived="$cache/Release"
stamp="$(date +%Y%m%d-%H%M%S)"
# Zusammenstellen außerhalb des Schreibtischs (iCloud): dort hängt macOS Finder-Infos an, und die strenge
# Signaturprüfung schlägt fehl (Gatekeeper meldet beim Empfänger dann „beschädigt“, Erfahrung aus MintMarkPDF).
work="$cache/Weitergabe/$stamp"
out="build/Weitergabe"
user="$(id -un)"   # nur zur Laufzeit, nie im Repo (S14)
maske() { sed "s#$HOME#~#g; s#$user#BENUTZER#g"; }
mkdir -p "$work/inhalt" "$work/pruefen" "$out"

bash Scripts/kurzanleitung.sh --pruefen || exit 1
echo "→ Release-Bau"
if ! xcodebuild -skipPackagePluginValidation -project TunnelTerminal.xcodeproj -scheme TunnelTerminal -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$derived" build > "$work/xcodebuild.log" 2>&1; then
  grep -E '(error|warning): ' "$work/xcodebuild.log" | maske | sort -u | head -20
  echo "✗ Release-Bau fehlgeschlagen"; exit 1
fi
app="$derived/Build/Products/Release/TunnelTerminal.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")"
echo "Version $version (Build $build)"

echo "→ Prüfungen"
fehler=0
codesign --verify --deep --strict "$app" 2> "$work/verify.txt" || { maske < "$work/verify.txt"; fehler=1; }
for f in "$app/Contents/MacOS/TunnelTerminal" "$app"/Contents/Helpers/*; do
  flags="$(codesign -dv "$f" 2>&1 | grep -oE 'flags=[^ ]+')"
  case "$flags" in *runtime*) echo "  $(basename "$f"): $flags" ;; *) echo "✗ ohne Hardened Runtime: $(basename "$f")"; fehler=1 ;; esac
done
# get-task-allow erlaubte das Anhängen eines Debuggers – auch an plink, das Passwörter über die Pipe bekommt (S8)
for f in "$app" "$app"/Contents/Helpers/*; do
  if codesign -d --entitlements - "$f" 2>/dev/null | grep -q get-task-allow; then echo "✗ get-task-allow: $(basename "$f")"; fehler=1; fi
done
[ "$fehler" = 0 ] && echo "  keine get-task-allow-Berechtigung (App und Hilfsprogramme)"
# Pfade mit Benutzernamen und der Benutzername selbst; erlaubt ist er nur in der Bundle-ID (de.<Name>.tunnelterminal,
# Name des Autors, M1)
benutzerordner='/Us''ers/'   # zusammengesetzt, damit der Grundsatz-Test „keine persönlichen Pfade“ diese Zeile nicht findet
treffer="$(LC_ALL=C grep -rlaF "$benutzerordner" "$app" | sed "s#$app/##")"
[ -n "$treffer" ] && { echo "✗ $benutzerordner in: $treffer" | maske; fehler=1; }
name="$(LC_ALL=C grep -raoE "[A-Za-z0-9._/-]*$user[A-Za-z0-9._/-]*" "$app" | sed "s#^$app/##" | grep -v "de\.$user\.tunnelterminal" | sort -u)"
[ -n "$name" ] && { echo "✗ Benutzername außerhalb der Bundle-ID:"; echo "$name" | maske | head -10; fehler=1; }
[ "$fehler" = 0 ] && echo "  keine Pfade mit Benutzernamen" || { echo "✗ Prüfung fehlgeschlagen – keine DMG"; exit 1; }

echo "→ DMG"
ditto --norsrc --noextattr --noqtn "$app" "$work/inhalt/TunnelTerminal.app"
xattr -cr "$work/inhalt/TunnelTerminal.app"
ln -s /Applications "$work/inhalt/Programme"
# Jeder Schritt einzeln geprüft (kein pipefail fürs ganze Skript: grep -q oben beendete die Pipe sonst mit SIGPIPE)
textutil -convert rtf -inputencoding UTF-8 -output "$work/inhalt/Zuerst lesen.rtf" Scripts/dmg/Zuerst-lesen.html \
  || { echo "✗ „Zuerst lesen“ fehlt"; exit 1; }
xattr -c "$work/inhalt/Zuerst lesen.rtf"
codesign --verify --deep --strict "$work/inhalt/TunnelTerminal.app" || { echo "✗ Signatur nach dem Kopieren ungültig"; exit 1; }
dmg="$work/TunnelTerminal-$version.dmg"
hdiutil create -volname "TunnelTerminal $version" -srcfolder "$work/inhalt" -fs HFS+ -format UDZO "$dmg" \
  > "$work/hdiutil.txt" 2>&1 || { grep -v deprecated "$work/hdiutil.txt" | maske; echo "✗ DMG nicht erstellt"; exit 1; }
[ -f "$dmg" ] || { echo "✗ DMG nicht erstellt"; exit 1; }
if hdiutil verify "$dmg" > "$work/verify-dmg.txt" 2>&1; then echo "  DMG-Prüfsumme intern gültig"
else tail -n 3 "$work/verify-dmg.txt" | maske; fehler=1; fi
if hdiutil attach -readonly -nobrowse -mountpoint "$work/pruefen" "$dmg" > /dev/null 2>&1; then
  ls -la "$work/pruefen" | maske
  codesign --verify --deep --strict "$work/pruefen/TunnelTerminal.app" && echo "  Signatur in der DMG gültig" || fehler=1
  echo "  Erweiterte Attribute der App: $(xattr "$work/pruefen/TunnelTerminal.app" | tr '\n' ' ')(leer = gut)"
  hdiutil detach "$work/pruefen" > /dev/null 2>&1 || hdiutil detach -force "$work/pruefen" > /dev/null 2>&1
else
  echo "✗ DMG ließ sich zum Prüfen nicht einhängen"; fehler=1
fi
[ "$fehler" = 0 ] || { echo "✗ DMG nicht weitergeben"; exit 1; }
[ -e "$out/TunnelTerminal-$version.dmg" ] && mv "$out/TunnelTerminal-$version.dmg" "$out/TunnelTerminal-$version-vorher-$stamp.dmg"
cp "$dmg" "$out/" || { echo "✗ Kopieren nach $out fehlgeschlagen"; exit 1; }
(cd "$out" && shasum -a 256 "TunnelTerminal-$version.dmg" > "TunnelTerminal-$version.dmg.sha256") \
  || { echo "✗ Prüfsumme nicht geschrieben"; exit 1; }
cat "$out/TunnelTerminal-$version.dmg.sha256"
echo "→ Weitergabe-Datei: $out/TunnelTerminal-$version.dmg ($(du -h "$out/TunnelTerminal-$version.dmg" | cut -f1))"
# Ohne Developer-ID ist die Prüfsumme der einzige Echtheitsnachweis: getrennt von der DMG schicken
echo "→ Prüfsumme getrennt von der DMG schicken (andere Nachricht, nicht dieselbe Mail oder AirDrop)."
