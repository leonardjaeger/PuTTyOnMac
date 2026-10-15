#!/bin/bash
# Baut plink, pscp, psftp und puttygen aus dem geprüften PuTTY-Tarball ohne GTK und legt sie signiert
# (Hardened Runtime) ins App-Paket nach Contents/Helpers (Plan M1, S7, S8, S14).
#
# Aufrufe:
#   aus Xcode (Run-Script-Phase „PuTTY-Werkzeuge bauen“): Ziel aus TARGET_BUILD_DIR/CONTENTS_FOLDER_PATH
#   Scripts/build-putty.sh <Zielordner>   – von Hand
#   Scripts/build-putty.sh --gpg-pruefen  – bei jedem Versionswechsel (braucht gpg mit dem PuTTY Release Key
#                                           und die Signatur Quellen/putty-<Version>.tar.gz.gpg)
#
# Versionswechsel (S7): VERSION, SHA256 (aus der offiziellen sha256sums-Liste) und ggf. GPG_FINGERPRINT ändern,
# --gpg-pruefen laufen lassen, prüfen, ob die Patches in Scripts/putty-patches/ noch nötig sind, Testlauf,
# Hinweis in docs/Stand.md.
set -euo pipefail

VERSION="0.85"
SHA256="13fd4db2936d03b73812a7bcc2a658e4dd29cc776a56c3670a7fc6f1a0ee8af8"
GPG_FINGERPRINT="1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5"   # PuTTY Release Key 2026 (M0, B10)
TOOLS=(plink pscp psftp puttygen)

root="$(cd "$(dirname "$0")/.." && pwd)"
tarball="$root/Quellen/putty-$VERSION.tar.gz"
# Außerhalb von iCloud bauen (M0, B16)
cache="$HOME/Library/Caches/SSH-App-Build/putty-$VERSION"
tool_path="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:/Applications/CMake.app/Contents/bin"

fail() { echo "error: $*" >&2; exit 1; }

[ -f "$tarball" ] || fail "Quellen/putty-$VERSION.tar.gz fehlt – offiziellen Tarball von https://www.chiark.greenend.org.uk/~sgtatham/putty/ laden."
actual="$(shasum -a 256 "$tarball" | cut -d' ' -f1)"
[ "$actual" = "$SHA256" ] || fail "Prüfsumme von putty-$VERSION.tar.gz stimmt nicht (S7) – Datei nicht verwenden."

if [ "${1:-}" = "--gpg-pruefen" ]; then
  PATH="$tool_path" command -v gpg >/dev/null || fail "gpg fehlt."
  status="$(PATH="$tool_path" gpg --status-fd 1 --verify "$tarball.gpg" "$tarball" 2>/dev/null || true)"
  echo "$status" | grep -q "^\[GNUPG:\] VALIDSIG .*$GPG_FINGERPRINT" \
    || fail "Keine gültige Signatur des PuTTY-Release-Schlüssels $GPG_FINGERPRINT."
  echo "GPG-Signatur gültig (Fingerabdruck $GPG_FINGERPRINT)."
  exit 0
fi

# Eigene Korrekturen an PuTTY (je Datei begründet, nur nach Leonards Zustimmung): Scripts/putty-patches/*.patch
shopt -s nullglob
patches=("$root"/Scripts/putty-patches/*.patch)
shopt -u nullglob
# Der Stempel deckt Quelle, Patches und dieses Skript ab (geänderte Flags bauen neu)
patch_sum="$(cat ${patches[@]+"${patches[@]}"} /dev/null | shasum -a 256 | cut -c1-16)"
script_sum="$(shasum -a 256 "$0" | cut -c1-16)"
stamp="$cache/fertig-$SHA256-$patch_sum-$script_sum"
if [ ! -f "$stamp" ]; then
  PATH="$tool_path" command -v cmake >/dev/null || fail "cmake fehlt (Homebrew oder CMake.app)."
  rm -rf "$cache"
  mkdir -p "$cache/src"
  tar -xzf "$tarball" -C "$cache/src" --strip-components 1
  for p in ${patches[@]+"${patches[@]}"}; do
    patch -p1 -F0 -s -d "$cache/src" < "$p" || fail "Patch $(basename "$p") passt nicht (mehr) – bei PuTTY-Update prüfen."
    echo "Patch angewendet: $(basename "$p")"
  done
  # Keine Pfade mit dem Benutzernamen in den Programmen (S14)
  map="-ffile-prefix-map=$cache/src=putty-src -ffile-prefix-map=$cache/bau=putty-bau"
  # Saubere Umgebung: die Xcode-Variablen sollen den PuTTY-Bau nicht beeinflussen
  if ! env -i HOME="$HOME" PATH="$tool_path" cmake -S "$cache/src" -B "$cache/bau" -DPUTTY_GTK_VERSION=NONE \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
      -DCMAKE_C_FLAGS="$map" > "$cache/konfig.log" 2>&1; then
    tail -40 "$cache/konfig.log"; fail "cmake-Konfiguration fehlgeschlagen."
  fi
  if ! env -i HOME="$HOME" PATH="$tool_path" cmake --build "$cache/bau" --target "${TOOLS[@]}" \
      -j "$(sysctl -n hw.ncpu)" > "$cache/bau.log" 2>&1; then
    tail -60 "$cache/bau.log"; fail "PuTTY-Bau fehlgeschlagen."
  fi
  for tool in "${TOOLS[@]}"; do
    strip -x "$cache/bau/$tool"
    # [s] statt s: der Grundsatz-Test sucht den wörtlichen Pfadanfang
    if strings "$cache/bau/$tool" | grep -qE '/User[s]/'; then fail "$tool enthält einen Pfad mit Benutzerordner (S14)."; fi
    libraries="$(otool -L "$cache/bau/$tool" | tail -n +2 | grep -v '/usr/lib/libSystem.B.dylib' || true)"
    [ -z "$libraries" ] || fail "$tool hängt an weiteren Bibliotheken: $libraries"
  done
  touch "$stamp"
fi

dest="${1:-${TARGET_BUILD_DIR:?}/${CONTENTS_FOLDER_PATH:?}/Helpers}"
mkdir -p "$dest"
identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
for tool in "${TOOLS[@]}"; do
  cp "$cache/bau/$tool" "$dest/$tool"
  codesign --force --options runtime --timestamp=none --sign "$identity" "$dest/$tool"
done
echo "PuTTY $VERSION: ${TOOLS[*]} nach $(basename "$(dirname "$dest")")/$(basename "$dest") kopiert und signiert."
