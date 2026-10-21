# M3 – Machbarkeit und Fakten (19.10.2026)

Gemessen auf dem Mac mit dem eigenen PuTTY-0.85-Bau (`build/m3/machbarkeit.sh`, `build/m3/probe.sh`, Wegwerf-Schlüssel
und -Server nur im Cache-Ordner) und im Quellcode von PuTTY 0.85. Platzhalter statt echter Namen und Adressen (S14).

## 1. GSSAPI abgeschaltet

- `Scripts/build-putty.sh` baut mit `-DPUTTY_GSSAPI=OFF` (`cmake/platforms/unix.cmake` setzt dann `NO_GSSAPI`; `unix/gss.c`
  und `ssh/pgssapi.c` entfallen). Ergebnis: `strings` findet in plink und puttygen **0×** `libgssapi` (vorher Liste der
  Bibliotheken für `dlopen`). Das Skript bricht ab, falls doch wieder ein Treffer auftaucht.
- Damit lädt plink keine fremde Bibliothek mehr, auch nicht über `GSSCustom` aus einer importierten Sitzung. Die
  Rückfrage aus M2 bei `GSSCustom` bleibt als Hinweis bestehen (sie schadet nicht und deckt Sitzungen ab, die eine
  fremde PuTTY-Installation lädt).

## 2. puttygen ohne Terminal

| Fall | Ergebnis |
|---|---|
| `-t ed25519 -C … -o x.ppk --new-passphrase /dev/fd/3` (Pipe) | Exit 0, Datei `0600`, `Encryption: aes256-cbc`; leere Pipe = ohne Passphrase |
| `x.ppk -L` / `-l` / `-l -E md5` ohne Passphrase | Exit 0: öffentlicher Teil einer .ppk ist unverschlüsselt |
| Privat exportieren ohne `--old-passphrase` | „Enter passphrase to load key:“, Exit 1 – **hängt nicht** (kein Steuerterminal) |
| `-O private-openssh --old-passphrase /dev/fd/3` | Exit 0, `0600`; `ssh-keygen -y` liest die Datei mit derselben Passphrase, Fingerabdruck gleich |
| Falsche Passphrase | „…: wrong passphrase“, Exit 1 |
| Verschlüsselte OpenSSH-Datei `-L` ohne Passphrase | Exit 1 („Enter passphrase …“): der öffentliche Teil braucht hier die Passphrase |
| OpenSSH → .ppk | Exit 0, öffentlicher Teil gleich |
| `-P` mit leerer neuer Passphrase | `Encryption: none` |
| ECDSA P-256 / RSA 4096 erzeugen | < 1 s / ca. 1 s |
| Ziel existiert schon | wird **ohne Rückfrage überschrieben** → die App fragt über den Sichern-Dialog |

Folgen: Passphrasen nur über Pipes ab fd 3 (`HelperProcess`), Dateien nur als absolute Pfade (`PuttygenCommand`),
Leser für Ausgaben und Fehlertexte im Kern. **plink lädt nur .ppk** – der Editor nimmt nur Dateien, die mit
`PuTTY-User-Key-File-` beginnen, und verweist für OpenSSH-Schlüssel auf das Fenster „Schlüssel“.

## 3. Bekannte Hostschlüssel (`sshhostkeys`)

### 3.1 Format
`unix/storage.c`: eine Zeile je Schlüssel `typ@port:server wert`, Server und Port wie in 3.4 aufbereitet, Vergleich
byteweise (`strncmp`). plink schreibt die Datei über eine Zwischendatei; ohne umask entsteht sie mit `0644` (gemessen) –
in der App gilt umask 077 (`0600`). `typ` ist PuTTYs `cache_id`:

| Typ | Wert (`*_cache_str`) |
|---|---|
| `ssh-ed25519` | `0x<x>,0x<y>` (Hex ohne führende Nullen, gemessen: x mit 63 Ziffern) |
| `ecdsa-sha2-nistp256/384/521` | `nistpNNN,0x<x>,0x<y>` |
| `rsa2` | `0x<e>,0x<n>` |
| `ssh-ed448`, `dss` | analog, **ohne gemessenen Vektor** → kein Fingerabdruck in der App |

### 3.2 Fingerabdruck
SHA256 über den öffentlichen Schlüssel im SSH-Format (RFC 4253 6.6, RFC 8709, RFC 5656), Base64 ohne „=“ – wie
`ssh-keygen -l` und plinks Abfrage. Ed25519: y als 32 Byte little-endian, oberstes Bit = Parität von x. ECDSA:
`04 || X || Y` mit fester Feldlänge (32/48/66). RSA: `mpint e`, `mpint n`. Gegen drei echte Wegwerf-Hostschlüssel
(sshd mit je einem Schlüssel, plink hat sie gespeichert) und `ssh-keygen -lf` geprüft → Testvektoren in
`KnownHostKeysTests`. Hash über CryptoKit (Richtlinien 3.2 Regel 10).

### 3.3 Port wie plink (Fehlerfund)
`settings.c`, `load_open_settings`: `PortNumber` gilt **nur**, wenn `Protocol` ein Verfahren von plink nennt (`ssh`,
`ssh-connection`, `telnet`, `rlogin`, `raw`, `serial`, `supdup`); sonst SSH auf Port **22** (gemessen:
Sitzung ohne `Protocol` mit `PortNumber=1` verbindet auf 22). Bis M2 zeigte die App für solche (importierten)
Sitzungen den falschen Port – im Inspektor, in der S4-Anzeige des Proxy-Befehls (`%port`) und jetzt auch für die
Passwort-Bindung und die Hostschlüssel. Behoben in `SessionFile.portNumber`; `setPortNumber` schreibt
`Protocol=ssh` dazu, wenn es fehlt (sonst wirkte der Port nicht).

### 3.4 Server und Benutzer wie plink (Befund des Prüfers)
`utils/sessprep.c` (`prepare_session`) bereitet `HostName` vor dem Verbinden auf: Leerzeichen vorn weg, ein
`benutzer@` bis zum **letzten** „@“ ersetzt `UserName`, ein **einzelnes** „:…“ außerhalb eckiger Klammern wird
verworfen (kein Port!), übrige Leerzeichen und Tabs entfallen. `ssh/ssh.c` (`ssh_hostport_setup`) nimmt für die
Hostschlüssel `LogHost` (Korrektur in der Härtung; vorher stand hier `LogicalHostName`), wenn gesetzt (Port dann 22 oder aus einem einzelnen „:port“), sonst den
aufbereiteten Server; `host_strduptrim` entfernt eckige Klammern um IPv6-Literale. Die App rechnet das byteweise nach
(`SessionFile.hostKeyServer`, `passwordTarget`; Tests `PlinkAddressTests`) – sonst gälte ein gespeichertes Passwort
für einen anderen Benutzer bzw. der Inspektor fände bekannte Schlüssel nicht.

## 4. Schlüsselbund

- **Datenschutz-Schlüsselbund nicht nutzbar:** `SecItemAdd` mit `kSecUseDataProtectionKeychain` liefert
  `-34018` (errSecMissingEntitlement) – die Ad-hoc-signierte App hat kein Team und damit keine Zugriffsgruppe.
- Deshalb Anmelde-Schlüsselbund (`kSecClassGenericPassword`, Dienst `de.leonardjaeger.tunnelterminal.passwort`,
  Konto = Sitzungsname, `kSecAttrGeneric` = `benutzer@server:port`). Er ist lokal (nie synchronisiert, App-Test) und
  erscheint in der Schlüsselbundverwaltung. Zugriff hat nur die App, die den Eintrag angelegt hat (Code-Signatur);
  **nach jedem neuen Bau fragt macOS einmal** („Immer erlauben“), weil sich die Ad-hoc-Signatur ändert.
- Gelesen werden zuerst nur die Merkmale (keine Rückfrage); das Passwort selbst nur, wenn das Ziel stimmt.

## 5. Passwort an plink

- `plink -load <Sitzung> -pwfile /dev/fd/3`; die App schreibt Passwort und Zeilenende mit `writev` in eine Pipe
  (vor dem Start, Obergrenze 4 KiB < Pipe-Puffer), schließt das Schreib-Ende und gibt das Lese-Ende als fd 3 weiter.
  Kein Eintrag in `ps` (App-Tests mit `/bin/sh` als Kind). M0 B5/B12: genau einmal verwendet; bei einer zweiten
  verdeckten Abfrage (2FA) bricht plink mit „Configured password was not accepted“ ab → die App bietet
  „Ohne gespeichertes Passwort verbinden“ an.
- Nicht verwendet bei Proxy (das Passwort könnte sonst schon am Proxy landen), ohne Benutzername, bei Telnet/Raw und
  mit `SSHManualHostKeys` (plink nähme dort genannte Schlüssel ohne Rückfrage an; eine untergeschobene Sitzung könnte
  das Passwort so an einen fremden Rechner lenken, S5).
- `umask` gilt für den ganzen Prozess: Starts von plink (Hauptthread) und puttygen (Hintergrund) laufen unter einer
  Sperre, sonst könnte ein Kind die lockere Maske der App erben (Test mit 40 gleichzeitigen Starts).

## 6. Agent

plink bekommt `SSH_AUTH_SOCK` aus der Umgebung der App (seit M1) und fragt ohne Schlüsseldatei zuerst den Agenten.
macOS-Agent: `ssh-add --apple-use-keychain <OpenSSH-Datei>` (Passphrase im Schlüsselbund),
nach einem Neustart `ssh-add --apple-load-keychain`. ssh-add versteht keine .ppk – Hinweis im Fenster „Schlüssel“.
