#!/bin/bash
# M0 Schritt 1: Werkzeuge und Voraussetzungen auf dem Mac prüfen (ändert nichts).
. build/m0/env.sh

echo "== System =="
sw_vers
uname -m

echo "== Xcode =="
xcode-select -p
xcrun swift --version 2>&1 | head -2
xcodebuild -version 2>&1 | head -2

echo "== Werkzeuge =="
for t in cmake gpg shasum curl codesign otool lsof nc; do
  printf '%-9s ' "$t"
  command -v "$t" >/dev/null && echo "vorhanden" || echo "FEHLT"
done
command -v cmake >/dev/null && cmake --version | head -1
command -v gpg >/dev/null && gpg --version | head -1

echo "== Entfernte Anmeldung (SSH auf localhost) =="
if nc -z -G 2 localhost 22 2>/dev/null; then
  echo "Port 22 auf localhost: offen – Entfernte Anmeldung ist an"
else
  echo "Port 22 auf localhost: zu – Entfernte Anmeldung ist aus"
fi

echo "== Quellen =="
if [ -f "$PUTTY_TARBALL" ]; then
  ls -l "$PUTTY_TARBALL" | awk '{print $5, $9}'
else
  echo "FEHLT: $PUTTY_TARBALL"
fi
ls Quellen/Vergleich-Builds 2>/dev/null || echo "Vergleich-Builds fehlen"
