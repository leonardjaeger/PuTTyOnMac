# M0-Recherche: plink (PuTTY 0.85) als Kindprozess einer macOS-App

Stand der Recherche: 14.10.2026. Quellen: offizielle PuTTY-Seiten (the.earth.li, chiark.greenend.org.uk) und Apple (developer.apple.com, support.apple.com).

**Hinweis zur Quellenlage:** Einige Primärquellen ließen sich mit den verfügbaren Werkzeugen nicht lesen:
- `git.tartarus.org` und `www.chiark.greenend.org.uk/~sgtatham/putty/keys.html` sperren automatisierten Abruf per robots.txt.
- Die Klartextdateien `sha256sums`/`*.gpg` unter the.earth.li wurden nur als Binärdaten geliefert.
- Die Shell hatte keinen Zugang zu den PuTTY-Hosts (Proxy 403).

Quellcode-Zitate stammen deshalb aus dem Fossies-Spiegel des offiziellen Tarballs `putty-0.85.tar.gz` (Sekundärspiegel, Pfad `putty-0.85/...`). Ersatzbelege dieser Art sind unten jeweils gekennzeichnet.

## Übersicht

| # | Frage | Antwort | Quelle |
|---|---|---|---|
| 1a | SHA-256 von `putty-0.85.tar.gz` | `13fd4db2936d03b73812a7bcc2a658e4dd29cc776a56c3670a7fc6f1a0ee8af8`. Der Wert stimmt mit dem Vergleichswert überein, aber **nur sekundär belegt**: Die offizielle `sha256sums` war nicht als Text lesbar. Zwei unabhängige Paketquellen geben genau diesen Wert an und berufen sich auf die offizielle Datei. **Vor Verwendung lokal prüfen** (siehe unten). | Primär (nicht lesbar): https://the.earth.li/~sgtatham/putty/0.85/sha256sums · sekundär: https://raw.githubusercontent.com/buildroot/buildroot/master/package/putty/putty.hash, https://raw.githubusercontent.com/Homebrew/homebrew-core/HEAD/Formula/p/putty.rb |
| 1b | URLs | Tarball: `https://the.earth.li/~sgtatham/putty/0.85/putty-0.85.tar.gz` · Signatur: `https://the.earth.li/~sgtatham/putty/0.85/putty-0.85.tar.gz.gpg` (Endung **`.gpg`**, 438 Byte, also eine abgetrennte Signatur) · Prüfsummen: `https://the.earth.li/~sgtatham/putty/0.85/sha256sums` · Signatur der Prüfsummen: `https://the.earth.li/~sgtatham/putty/0.85/sha256sums.gpg`. Die Download-Seite verlinkt dieselben Dateien unter `.../putty/latest/...`. | https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html · Verzeichnisliste https://the.earth.li/~sgtatham/putty/0.85/ |
| 2a | Release-Schlüssel für 0.85 | **„Release Key (2026)“**, RSA 3072, Key-ID `5C67D0F88BC3E5B5`, Fingerabdruck **`1A07 DAC0 F220 CF12 248E A719 5C67 D0F8 8BC3 E5B5`** – Schlussfolgerung, nicht wörtlich belegt (Begründung unten). | https://the.earth.li/~sgtatham/putty/0.85/htmldoc/AppendixF.html (Abschnitte F.1, F.3) |
| 2b | Download des öffentlichen Schlüssels | `https://www.chiark.greenend.org.uk/~sgtatham/putty/keys/release-2026.asc` (Master-Key 2026: `.../keys/master-2026.asc`, Fingerabdruck `371C 662B 855F 318F F63A D091 D732 471F 094D 5FB5`) | wie 2a |
| 2c | Signaturdatei / sind die sha256sums signiert? | Signaturdateien = Dateiname + `.gpg`. **Ja**, zu jeder Prüfsummendatei gibt es eine Signatur: `md5sums.gpg`, `sha1sums.gpg`, `sha256sums.gpg`, `sha512sums.gpg`. Ob es abgetrennte oder Klartext-Signaturen sind, ist nicht belegt; die Größe (17 K gegenüber 16 K bei `sha256sums`) spricht eher für eine Klartext-Signatur. | https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html · https://the.earth.li/~sgtatham/putty/0.85/ |
| 3 | `-pwfile` | Seit **0.77**. Liest **nur die erste Zeile**. Ein abschließendes **CR/LF wird entfernt** (`chomp`). Das Passwort wird **genau einmal** verwendet; wird es abgelehnt, bricht plink mit „Configured password was not accepted“ ab, statt interaktiv nachzufragen (seit 0.77). Es gilt nur für eine Eingabeaufforderung mit **genau einem nicht-echoenden Prompt, der an den Server geht** (`to_server`), also nicht für Passphrasen privater Schlüssel. Für keyboard-interactive: **nicht eindeutig belegt** (siehe unten). Nur mit SSH nutzbar. | Doku 3.11.3.8: https://the.earth.li/~sgtatham/putty/0.85/htmldoc/Chapter3.html · Changes: https://www.chiark.greenend.org.uk/~sgtatham/putty/changes.html · Wishlist: https://www.chiark.greenend.org.uk/~sgtatham/putty/wishlist/cmdline-pw-fallback-to-interactive.html · Code (Spiegel): https://fossies.org/linux/misc/putty-0.85.tar.gz/putty-0.85/cmdline.c |
| 4a | SIGWINCH in Unix-plink | **Ja.** plink installiert einen SIGWINCH-Handler, liest die Größe per `ioctl(STDIN_FILENO, TIOCGWINSZ)` und meldet sie mit `backend_size()` an den Server. Wenn stdin kein Terminal ist, schlägt das `ioctl` fehl und es wird nichts gemeldet. Die Doku erwähnt das nicht. | Code (Spiegel): https://fossies.org/linux/putty/unix/plink.c (0.85; Z. 501–507, 636–637, 882, 888) |
| 4b | Pseudo-Terminal erzwingen/verbieten | `-t` = Pseudo-Terminal anfordern, `-T` = keines anfordern. Ist ein Remote-Befehl angegeben, setzt plink standardmäßig „kein PTY“ (`CONF_nopty`). | Doku 3.11.3.12: https://the.earth.li/~sgtatham/putty/0.85/htmldoc/Chapter3.html · Chapter7 (Usage-Liste): https://the.earth.li/~sgtatham/putty/0.85/htmldoc/Chapter7.html · Code Z. 799 (Spiegel, s. o.) |
| 5a | `PUTTY_GTK_VERSION=NONE` | Offiziell unterstützter Wert (`ANY 3 2 1 NONE`). Mit NONE bleibt `GTK_FOUND=FALSE`. **`plink`, `pscp`, `psftp`, `psocks`, `puttygen`, `pageant`, `psusan`, `uppity`** werden trotzdem gebaut, denn sie liegen außerhalb von `if(GTK_FOUND)` und nutzen `no-gtk.c`. Nur `putty`, `pterm`, `puttytel` (+ App-Varianten) brauchen GTK. Es gibt keine Doku-Seite dazu; Beleg ist nur der Code. | Code (Spiegel, 0.85): https://fossies.org/linux/putty/cmake/gtk.cmake · https://fossies.org/linux/putty/unix/CMakeLists.txt (Z. 73–75, 99, 137) |
| 5b | CMake-Mindestversion | `cmake_minimum_required(VERSION 3.7...3.28)`, also **mindestens CMake 3.7** (Policy-Bereich bis 3.28). | Code (Spiegel, 0.85): https://fossies.org/linux/putty/CMakeLists.txt |
| 6a | `com.apple.security.inherit` | Das Hilfsprogramm muss **genau zwei** Sandbox-Entitlements haben: `com.apple.security.app-sandbox` + `com.apple.security.inherit`. Hat es weitere, bricht das System den Kindprozess ab (Absturz mit Code-Signing-Fehler). `get-task-allow` ist unverträglich, deshalb `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` abschalten. Ablageort: `Contents/MacOS`. Erlaubt ist der Start per `NSTask`/`Process` oder `posix_spawn`. Die Haupt-App selbst darf `inherit` nie haben. | https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app · https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html |
| 6b | Erbt das Kind die NSOpenPanel-Freigaben? | **Nein.** Das Kind erbt *nur* die statischen Rechte aus der Entitlement-Datei der Haupt-App, *nicht* zur Laufzeit hinzugekommene Rechte (PowerBox/Open-Panel). Lösung: Daten übergeben oder ein Bookmark an das Kind weiterreichen. | Entitlement Key Reference (s. o.), Abschnitt „Enabling App Sandbox Inheritance“ · https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox |
| 6c | Serielle Geräte `/dev/cu.*` | Entitlement **`com.apple.security.device.serial`** („Interaction with serial devices“). Dafür gibt es keine Xcode-Checkbox; es muss manuell eingetragen werden. Belegt nur in der archivierten Entitlement Key Reference (Tabelle 4-7) und in einer Forenantwort von Apple-DTS. In der aktuellen Doku gibt es keine eigene Seite (der Abruf von `.../com.apple.security.device.serial` schlug fehl). Es ist ein Sandbox-Entitlement, ein Kind mit `inherit` darf es also nicht selbst tragen: Die **Haupt-App** muss es haben. | https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html · https://developer.apple.com/forums/thread/94177 |
| 6d | Ausgehende TCP-Verbindungen | **`com.apple.security.network.client`** („may open outgoing network connections“). Bei TCP wird nur der Verbindungs*aufbau* beschränkt, nicht der Datenfluss. In Xcode: App Sandbox → Outgoing Connections (Client). | https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client |
| 6e | HOME / `~` im Kindprozess | Für die App belegt: `NSHomeDirectory()` liefert in der Sandbox das **Sandbox-Verzeichnis** der App. Der Container liegt unter `~/Library/Containers/<Bundle-ID>`. Was die **Umgebungsvariable `HOME`** des Kindprozesses enthält (Container oder echtes Home), ist **nicht belegt**. Das muss im Test geprüft werden. Laut Apple-DTS erbt ein Hilfsprogramm die Sandbox des Elternprozesses standardmäßig. | https://developer.apple.com/documentation/foundation/nshomedirectory() · https://developer.apple.com/documentation/security/migrating-your-app-s-files-to-its-app-sandbox-container · https://developer.apple.com/forums/thread/123873 |
| 7a | Pfad „Entfernte Anmeldung“ (macOS 14+) | Apple-Menü → **Systemeinstellungen → Allgemein → Teilen** → „Entfernte Anmeldung“ (Remote Login) einschalten. Optional über das Info-Symbol „Allow access for“ (alle oder ausgewählte Benutzer) und „Allow full disk access for remote users“ einstellen. | https://support.apple.com/guide/mac-help/mchlp1066/14.0/mac/14.0 · https://support.apple.com/guide/mac-help/mchlp1066 |
| 7b | `systemsetup -getremotelogin` | `-getremotelogin` ist in Apples Doku **nicht aufgeführt**; dort steht nur `-setremotelogin on|off` mit der Anweisung, `systemsetup` mit `sudo` aufzurufen. Seit macOS 10.15 braucht `-setremotelogin` außerdem **Festplattenvollzugriff** für den aufrufenden Prozess. Ob `-getremotelogin` Root braucht, ist **nicht belegt**. | https://support.apple.com/guide/remote-desktop/apd95406b8d/mac · https://support.apple.com/en-us/HT210595 |

## Erläuterungen

### 1. Prüfsumme und Dateien
- Laut Download-Seite: „Currently this is 0.85, released on 2026-08-16.“ Die Verzeichnisliste unter `/0.85/` enthält: `putty-0.85.tar.gz` (2,9 MB, 14.08.2026), `putty-0.85.tar.gz.gpg` (438 B, 16.08.2026), `md5sums`/`sha1sums`/`sha256sums`/`sha512sums` jeweils mit `.gpg`.
- Lokale Pflichtprüfung (der SHA-256-Wert ist nur über Sekundärquellen bestätigt):
  ```sh
  gpg --import release-2026.asc
  gpg --verify sha256sums.gpg            # ggf. gpg --verify sha256sums.gpg sha256sums
  gpg --verify putty-0.85.tar.gz.gpg putty-0.85.tar.gz
  shasum -a 256 putty-0.85.tar.gz        # erwartet 13fd4db2…a0ee8af8
  ```

### 2. Schlüssel
- Appendix F (Doku 0.85) führt als aktuelle Schlüssel nur die „2026“-Generation (F.1); die 2023-Schlüssel stehen unter „Key rollover“ (F.3). Grundsatz: „Each release is signed with the Release Key that was current at the time of release.“ Daraus folgt, dass 0.85 mit dem Release Key 2026 signiert ist. **Eine ausdrückliche Aussage „0.85 ist mit Schlüssel X signiert“ gibt es nicht.**
- Widerspruch in der Quelle: F.3 enthält noch den Satz „Our current keys were generated in July 2023.“ Fällt die Prüfung mit dem 2026-Schlüssel fehl, ist der 2023-Release-Key der Kandidat: `F412 BA3A A30F DC0E 77B4 E387 1993 D21B CAD1 AA77`, `.../keys/release-2023.asc`.
- `keys.html` auf chiark war wegen robots.txt nicht abrufbar. Die Angaben stammen aus Appendix F derselben Version.

### 3. `-pwfile` (Code aus `putty-0.85/cmdline.c`, Spiegel)
- Einlesen (Z. 641, 650): `FILE *fp = f_open(fn, "r", false);` … `cmdline_password = chomp(fgetline(fp));`. `fgetline` liest eine Zeile. `chomp` (`utils/chomp.c`) entfernt **alle** abschließenden `\r`/`\n`, sonst nichts (keine Leerzeichen).
- Bedingung (Z. 96): `if (p->n_prompts != 1 || p->prompts[0]->echo || !p->to_server) return SPR_INCOMPLETE;`. Laut Kommentar soll das Passwörter vorbelegen, aber keine Passphrasen privater Schlüssel.
- Nur einmal (Z. 104–105): `if (state->tried) return SPR_SW_ABORT("Configured password was not accepted");`. plink ruft das mit `restartable=false` auf (unix/plink.c Z. 389), danach wird das Passwort aus dem Speicher gelöscht.
- keyboard-interactive: In der Doku nicht erwähnt. Laut Code wird `-pwfile` für eine KI-Runde nur genutzt, wenn sie genau **einen** nicht-echoenden Prompt mit `to_server` enthält. Ob KI-Prompts `to_server` setzen, konnte nicht geprüft werden (Funktionsrumpf `ssh2_userauth_ki_setup_prompts` nicht lesbar). **Nicht belegt, im Test prüfen.**
- Doku-Hinweis: „`-pw` is retained for backwards compatibility only; you should use `-pwfile` instead.“

### 4. SIGWINCH / PTY
- Handler `sigwinch()` schreibt in eine Signal-Pipe (Z. 501–507). In der Hauptschleife folgt dann `ioctl(STDIN_FILENO, TIOCGWINSZ, ...)` und anschließend `backend_size(backend, size.ws_col, size.ws_row)` (Z. 636–637). Die Anfangsgröße liest plink beim Start (Z. 888).
- Lokaler Raw-Modus nur, wenn `tcgetattr(STDIN_FILENO, …)` gelingt (`local_tty`, Z. 980).
- Folge für die App: plink muss an einem **PTY als stdin** laufen. Die App muss die Fenstergröße per `TIOCSWINSZ` auf dem PTY setzen; der Kernel sendet dann SIGWINCH an plink.
- Doku Chapter 7: Interaktive Sitzungen sind „not the main point of Plink“, Terminalemulation in Plink steht auf der Non-Wish-Liste (https://www.chiark.greenend.org.uk/~sgtatham/putty/wishlist/plink-terminal.html). Die Emulation muss also die App selbst übernehmen.

### 5. Build ohne GTK
- `cmake/gtk.cmake`: `set(GTK_FOUND FALSE)`. Die pkg-config- und gtk-config-Suche läuft nur bei `ANY` oder passender Versionsnummer. Eingeführt mit Commit „Add explicit cmake setting for 'build without GTK'“ (18.09.2022).
- Beispiel: `cmake -S putty-0.85 -B build -DPUTTY_GTK_VERSION=NONE && cmake --build build --target plink pscp psftp puttygen`.

### 6. Sandbox
- Apple bevorzugt für Privilegientrennung XPC-Dienste; ein Kindprozess mit `inherit` ist zulässig, bietet aber weniger Schutz.
- Ein Hilfsprogramm mit `inherit` kann **nicht debuggt** werden (kein `get-task-allow`). Apple empfiehlt dafür ein separates, nicht gesandboxtes Debug-Target.
- Auf Dateien, die der Nutzer gewählt hat (z. B. Schlüsseldatei, `-pwfile`-Datei), hat das Kind keinen Zugriff. Optionen: Datei in den App-Container kopieren, oder ein Bookmark ohne Security-Scope übergeben, das das Kind auflöst. Letzteres braucht Code im Kind, für ein unverändertes plink also ungeeignet.

### 7. Entfernte Anmeldung
- Wenn die App den Zustand prüfen will: `systemsetup` ist laut Apple mit `sudo` aufzurufen. Aus einer gesandboxten App heraus ist das praktisch nicht nutzbar. Ein Root-freier Weg ist nicht belegt.
