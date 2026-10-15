#!/bin/bash
# M0 Schritt 3: plink, pscp, psftp, puttygen aus dem geprüften Tarball ohne GTK bauen und vergleichen.
set -eu
. build/m0/env.sh
command -v cmake >/dev/null || { echo "cmake fehlt"; exit 2; }

ist=$(shasum -a 256 "$PUTTY_TARBALL" | cut -d' ' -f1)
[ "$ist" = "$PUTTY_SHA256" ] || { echo "Prüfsumme falsch – Abbruch"; exit 1; }

rm -rf "$PUTTY_SRC" "$PUTTY_BUILD"
mkdir -p "$PUTTY_SRC"
tar -xzf "$PUTTY_TARBALL" -C "$PUTTY_SRC" --strip-components 1

root="$(pwd)"
# Keine Pfade mit dem Benutzernamen in den Binärdateien (S14)
map="-ffile-prefix-map=$root/$PUTTY_SRC=putty-src -ffile-prefix-map=$root/$PUTTY_BUILD=putty-bau"
start=$(date +%s)
cmake -S "$PUTTY_SRC" -B "$PUTTY_BUILD" -DPUTTY_GTK_VERSION=NONE \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DCMAKE_C_FLAGS="$map" > build/m0/cmake-konfig.log 2>&1 || { tail -40 build/m0/cmake-konfig.log; exit 1; }
cmake --build "$PUTTY_BUILD" --target plink pscp psftp puttygen -j "$(sysctl -n hw.ncpu)" > build/m0/cmake-bau.log 2>&1 \
  || { tail -60 build/m0/cmake-bau.log; exit 1; }
echo "Bauzeit: $(( $(date +%s) - start )) s"
echo "Warnungen beim Bauen: $(grep -c 'warning:' build/m0/cmake-bau.log || true)"

for b in plink pscp psftp puttygen; do
  f="$PUTTY_BUILD/$b"
  echo "== $b =="
  file "$f"
  ls -l "$f" | awk '{print "Größe:", $5, "Bytes"}'
  otool -L "$f" | tail -n +2
  echo "Treffer /Users/ in strings: $(strings "$f" | grep -c '/Users/' || true)"
done
echo "== plink -V (eigener Build) =="
"$PUTTY_BUILD/plink" -V 2>&1 || true

echo "== Vergleich mit dem Vergleichs-Build aus Quellen/ (Kopie, Original bleibt unverändert) =="
mkdir -p build/m0/vergleich
cp Quellen/Vergleich-Builds/plink build/m0/vergleich/plink
chmod +x build/m0/vergleich/plink
build/m0/vergleich/plink -V 2>&1 || true
otool -L build/m0/vergleich/plink | tail -n +2
ls -l build/m0/vergleich/plink | awk '{print "Größe:", $5, "Bytes"}'
