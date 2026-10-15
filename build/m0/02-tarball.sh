#!/bin/bash
# M0 Schritt 2: PuTTY-Tarball prüfen (SHA-256 fest, offizielle sha256sums, GPG-Signatur).
set -u
. build/m0/env.sh
D="build/m0/pruefung"
mkdir -p "$D"
fail=0

ist=$(shasum -a 256 "$PUTTY_TARBALL" | cut -d' ' -f1)
echo "SHA-256 ist:      $ist"
echo "SHA-256 erwartet: $PUTTY_SHA256"
[ "$ist" = "$PUTTY_SHA256" ] && echo "-> stimmt mit dem fest hinterlegten Wert überein" || { echo "-> ABWEICHUNG"; fail=1; }

base="https://the.earth.li/~sgtatham/putty/0.85"
keys="https://www.chiark.greenend.org.uk/~sgtatham/putty/keys"
for f in sha256sums sha256sums.gpg putty-0.85.tar.gz.gpg; do
  curl -fsSL -o "$D/$f" "$base/$f" || { echo "Download fehlgeschlagen: $f"; fail=1; }
done
for k in release-2026.asc release-2023.asc; do
  curl -fsSL -o "$D/$k" "$keys/$k" || echo "Schlüssel nicht geladen: $k"
done

offiziell=$(grep -E '(^|[ /*])putty-0\.85\.tar\.gz$' "$D/sha256sums" | awk '{print $1}' | head -1)
echo "SHA-256 offiziell (sha256sums): ${offiziell:-nicht gefunden}"
[ "$offiziell" = "$ist" ] && echo "-> stimmt mit der offiziellen Liste überein" || { echo "-> ABWEICHUNG zur offiziellen Liste"; fail=1; }

if command -v gpg >/dev/null; then
  export GNUPGHOME="$D/gnupg"
  rm -rf "$GNUPGHOME"; mkdir -m 700 "$GNUPGHOME"
  gpg --batch --quiet --import "$D"/release-*.asc 2>&1
  gpg --batch --fingerprint 2>&1 | sed -n '/^pub/,/^$/p'
  echo "== Signatur des Tarballs =="
  out=$(gpg --batch --status-fd 1 --verify "$D/putty-0.85.tar.gz.gpg" "$PUTTY_TARBALL" 2>&1)
  echo "$out" | grep -E 'VALIDSIG|BADSIG|NO_PUBKEY|ERRSIG'
  echo "$out" | grep -q 'VALIDSIG' || { echo "-> Signatur NICHT gültig"; fail=1; }
  echo "== Signatur der sha256sums =="
  # abgetrennte Signatur oder Klartext-Signatur – beides ist laut Recherche möglich
  out=$(gpg --batch --status-fd 1 --verify "$D/sha256sums.gpg" "$D/sha256sums" 2>&1) \
    || out=$(gpg --batch --status-fd 1 --verify "$D/sha256sums.gpg" 2>&1)
  echo "$out" | grep -E 'VALIDSIG|BADSIG|NO_PUBKEY|ERRSIG'
  echo "$out" | grep -q 'VALIDSIG' || { echo "-> Signatur NICHT gültig"; fail=1; }
  echo "Erwartete Fingerabdrücke (laut Recherche, bitte gegen VALIDSIG vergleichen):"
  echo "  Release Key 2026: 1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5"
  echo "  Release Key 2023: F412BA3AA30FDC0E77B4E3871993D21BCAD1AA77"
else
  echo "gpg nicht vorhanden – Signaturdateien liegen in $D, Prüfung erfolgt dann in der Cloud."
fi
exit "$fail"
