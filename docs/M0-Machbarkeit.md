# M0 – Machbarkeitstest

**Stand:** 15.10.2026 · **Status:** abgenommen am 15.10.2026 · gehört zu Plan Abschnitt 5 (M0)

Quellen der Fakten: `docs/M0-Recherche.md` (PuTTY, Apple), der PuTTY-0.85-Quellcode (geprüfter Tarball), der SwiftTerm-Quellcode (Tag 1.99.0) und die Messungen auf Leonards Mac (Xcode 27, Apple Silicon) am 14./15.10.2026. Benutzername, Hostschlüssel-Fingerabdrücke und Rechnername stehen bewusst nicht in dieser Datei (S14).

---

## 1. Befunde

| Nr. | Befund | Folge |
|---|---|---|
| B1 | **SwiftTerm 1.99.0** (Tag vom 08.10.2026, Commit `2dad6a1e516f755bed77cf9bbd09455062f54758`) ist die neueste Version; das Paket verlangt Swift-Tools 6.2 (Xcode 26 oder neuer) und läuft ab macOS 11 | Pin auf `exact: "1.99.0"` (S7). Mit Xcode 27 gebaut: 0 Kompilierfehler |
| B2 | `LocalProcessTerminalView` (Weg A) startet den Prozess mit `forkpty` + `execve`. Das Kind erbt **jeden** offenen Deskriptor ohne `FD_CLOEXEC` | **gemessen:** plink erbt fd 3–6 der App – die Metal-Bibliothek und **zwei beschreibbar geöffnete** Metal-Cachedateien der App (M5). Weg A ist für die App ungeeignet |
| B3 | `LocalProcessTerminalView` beantwortet eine OSC-52-Leseanfrage mit dem Inhalt der Zwischenablage und schreibt OSC 52 ohne Rückfrage in die Zwischenablage. Die Methoden sind `public`, nicht `open` | **gemessen (M10):** Weg A hat einen Testtext ohne Rückfrage in die Zwischenablage geschrieben und auf `printf '\033]52;c;?\a'` dessen Base64 an den Server geschickt. Verstößt gegen **S11** |
| B4 | **Weg B:** SwiftTerms `TerminalView` + eigener Start mit `posix_spawn` (`POSIX_SPAWN_SETSID`, `…CLOEXEC_DEFAULT`, `…SETSIGDEF`, `…SETSIGMASK`), eigene PTY. Nur 0/1/2 und fd 3 (Passwort) gehen ans Kind; OSC 52 und Links werden abgelehnt | **gemessen:** plink hat nur fd 0–3 geerbt (M5), OSC 52 Lesen und Schreiben abgelehnt (M10). plink hat **kein Steuerterminal** (`ps`-Spalte TTY `??`; der Slave wird mit `O_NOCTTY` geöffnet und per `adddup2` übergeben, das macht nie ein Steuerterminal) – die App schickt nach jeder Größenänderung selbst `SIGWINCH`; das funktioniert (M2). Folge für M1: Ctrl-C erzeugt bei plinks lokalen Abfragen (Hostschlüssel, Passwort) kein SIGINT – die App braucht einen eigenen „Abbrechen“-Weg |
| B5 | `-pwfile` (seit 0.77): erste Zeile, Zeilenende entfernt, **genau einmal** verwendet; bei Ablehnung Abbruch („Configured password was not accepted“) | M3/M4 bestätigt. Die App muss bei Abbruch „Passwort falsch – neu eingeben?“ anbieten |
| B6 | Laut Apple-Doku erbt ein Kind mit `inherit` die Freigaben aus dem Öffnen-Dialog **nicht** | **Widerlegt (M6):** In der Sandbox-App hat plink die im Öffnen-Dialog gewählte Schlüsseldatei über ihren Originalpfad gelesen („Server refused our key“ = Datei geladen, Schlüssel nur nicht hinterlegt). Gemessen mit Weg A; für Weg B nicht gesondert gemessen |
| B7 | Serielle Geräte in der Sandbox brauchen `com.apple.security.device.serial` an der **App** | M8: ok |
| B8 | Was steht im Kindprozess der Sandbox in `HOME`? | M9: `HOME` und `PUTTYDIR` liegen im Container der App |
| B9 | Schlüsselbund ohne Entwickleraccount: ad hoc Signatur ändert sich bei jedem Bau | **gemessen:** Beim ersten Zugriff jeder App-Variante und nach einem Bau an neuem Ort fragte macOS nach; nach „Immer erlauben“ kam bei einem späteren Neubau keine Frage mehr. Das Verhalten ist nicht sicher vorhersagbar → Entscheidung in M3 (Abschnitt 4) |
| B10 | GPG: **bestätigt am 15.10.2026** – Tarball und `sha256sums` gültig signiert vom „Release Key 2026“ (`VALIDSIG 1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5`, Signatur vom 16.08.2026). Der Release Key 2023 ist seit 09.08.2026 abgelaufen | `Scripts/build-putty.sh` (M1) prüft SHA-256 fest; GPG bei Versionswechsel (auf dem Mac fehlt `gpg`) |
| B11 | **PuTTY-Fehler: Unix-plink 0.85 übernimmt `$TERM` nicht.** `platform_default_s()` in `unix/plink.c` fragt den Schlüssel „TermType“ ab, die Einstellung heißt aber „TerminalType“ (`conf.h`) – plink meldet dem Server immer `xterm` | gemessen: `echo $TERM` = `xterm`. Abhilfe gemessen: `TerminalType=xterm-256color` in `PUTTYDIR/sessions/Default%20Settings` → `xterm-256color`, `tput colors` = 256. Kandidat für einen Fehlerbericht an PuTTY |
| B12 | `-pwfile` wird laut Quellcode (`cmdline.c`, `cmdline_get_passwd_input`) bei der **ersten** Abfrage mit genau einem verdeckten Feld an den Server eingesetzt – also auch bei keyboard-interactive mit einer „Password:“-Zeile (so meldet sich macOS an). Der Zustand wird nie zurückgesetzt: **jede weitere** solche Abfrage (z. B. 2FA, die je Runde ein Feld schickt, oder ein zweiter Passwortversuch) endet mit „Configured password was not accepted“, ohne Rückfall auf die normale Abfrage. Nur Abfragen mit mehreren Feldern, sichtbare Abfragen und lokale Abfragen (Passphrase) gehen normal an den Nutzer | M3/M4: Anmeldung ohne Abfrage. Für M1: Nach genau dieser Meldung „ohne gespeichertes Passwort erneut verbinden“ anbieten – sonst scheitern 2FA-Server dauerhaft |
| B13 | Weg B, erster Versuch: Größe per `TIOCSWINSZ` auf dem Master gesetzt, **bevor** die Slave-Seite offen war → plink las 0×0 (`stty size` = `0 0`) | Behoben: App öffnet den Slave selbst (`O_NOCTTY`), setzt die Größe über den **Master**, solange der Slave offen ist, und gibt genau diesen Deskriptor per `adddup2` an 0/1/2 weiter (kein zweites Öffnen über den Pfad) |
| B14 | **App Sandbox sperrt Terminal-Steuerbefehle auf `/dev/ttys*`** (Systemprotokoll `deny(1) file-ioctl path:/dev/ttys…`): `TIOCSWINSZ` (`"t" 103`), `TIOCSCTTY` (`"t" 97`), `TIOCSETA`/`TIOCSETAW` (`"t" 20/21`). Auf dem Master (`/dev/ptmx`) sind dieselben Befehle erlaubt | Folgen in der Sandbox: plink kann **den Rohmodus nicht setzen** → Eingaben erscheinen doppelt, vim zeigt Terminal-Antworten als Text, und **ein an plinks Abfrage getipptes Passwort ist sichtbar** (am 15.10. leider tatsächlich passiert). Weg A bekommt in der Sandbox zusätzlich keine Startgröße und kein Steuerterminal |
| B15 | **plink bindet vor jeder TCP-Verbindung an Port 0** (`unix/network.c`, Z. 618–668; der Code fragt selbst „Why do we bother doing the bind when localport == 0 anyway?“). Die Sandbox wertet das als `network-bind` | Sandbox-App braucht zusätzlich `com.apple.security.network.server` (gemessen: ohne → „Operation not permitted“, mit → Verbindung steht). Für `-L`/`-D` wäre das ohnehin nötig |
| B16 | **Leonards Schreibtisch liegt in iCloud Drive.** Der Dateianbieter setzt laufend `com.apple.FinderInfo` und `com.apple.fileprovider.fpfs#P` auf App-Pakete; `codesign` bricht dann ab („resource fork, Finder information, or similar detritus not allowed“), auch nach `xattr -cr` | Signierte Pakete nie im Projektordner bauen: Prototyp jetzt unter `~/Library/Caches/SSH-App-Build/m0-out`; für M1 gilt dasselbe (DerivedData liegt schon dort) |
| B17 | PuTTY zeigt nach der Anmeldung „Access granted. Press Return to begin session.“ (Schutz gegen gefälschte Abfragen, `ssh/connection2.c`) und wartet auf eine Zeile. Das passiert nur, wenn stdin ein Terminal ist und `-no-antispoof` fehlt | In M1 bewusst entscheiden: Hinweis anzeigen und Return durchreichen **oder** `-no-antispoof` setzen (die App zeigt Abfragen ohnehin selbst an). Im Rohmodus kommt Return als CR an und plink wartet weiter (`unix/console.c` wartet auf `\n`) – erst LF (Ctrl-J) startet die Sitzung (gemessen in der Sandbox mit vorab gesetztem Rohmodus) |
| B18 | Beobachtung: Terminalfenster im Hintergrund wurden manchmal erst nach einer Größenänderung neu gezeichnet; ein Weg-A-Fenster nahm nach dem OSC-52-Test keine Eingaben mehr an | Nicht weiter untersucht (Weg A entfällt; Hintergrund-Zeichnen kann an der Steuerung im Hintergrund liegen). In M1 beim normalen Arbeiten beobachten |

---

## 2. Messergebnisse

Ablauf über den Bauwächter (Modus `skript`, je Schritt `build/m0/cmd.sh`). Oberflächentests per Computer-Steuerung im Hintergrund; das Passwort hat ausschließlich Leonard eingegeben (Fenster bzw. „Testpasswort ablegen…“).

| Nr. | Prüfung | Ergebnis ohne Sandbox | Ergebnis mit Sandbox |
|---|---|---|---|
| M1 | Verbinden A und B, Hostschlüssel-Abfrage, Anmeldung, `vim`, `top`, Umlaute (`äöüß ÄÖÜ €`), 256 Farben | **ok** (A und B): Hostschlüssel-Abfrage, Anmeldung per getipptem Passwort (B), Umlaute, `xterm-256color` (nach B11-Abhilfe), `tput colors` = 256, 256-Farben-Tabelle und Truecolor korrekt, `vim` mit Syntaxfarben, `top`. `htop` ist auf dem Mac nicht installiert und wurde nicht gemessen | **nur eingeschränkt (B14).** Drei Bauten: (1) **Weg B ohne Gegenmaßnahme** (Bau vor dem Rohmodus-Versuch): Verbindung, Umlaute, 256 Farben ok, aber doppelte Eingaben und `vim` zeigt Terminal-Antworten als Text; laut Protokoll `deny … "t" 20/21` für plink, `stty` des PTY zeigt `icanon echo`. (2) **Weg A, Test 5** (Rohmodus-Versuch betrifft nur Weg B): Das an plinks Passwortabfrage getippte Passwort war **sichtbar**. (3) **Weg B mit vorab von der App gesetztem Rohmodus** (`cfmakeraw` über den Master, nur Sandbox): `vim` sauber, aber Zeilenumbrüche des Servers kommen ohne CR an (plink meldet dem Server die lokalen Modi aus `orig_termios`) und „Press Return“ braucht LF (B17) |
| M2 | Fenstergröße ändern → `stty size`, `top` | **ok**: A und B 102×31 → 77×23; `top` passt sich im Lauf an (B per manuellem `SIGWINCH`) | **ok** für B (Größe über den Master gesetzt); A startet laut Protokoll ohne Größe (B14) |
| M3 | Schlüsselbund-Passwort, Weg A (`/dev/fd/<n>`) | **ok**: Anmeldung ohne Abfrage über `/dev/fd/4` | nicht gemessen (Weg A entfällt) |
| M4 | Schlüsselbund-Passwort, Weg B (`/dev/fd/3`) | **ok**: Anmeldung ohne Abfrage | **ok** (nach B15-Abhilfe), Schlüsselbund-Rückfrage siehe B9 |
| M5 | Prozessliste und Deskriptoren während M3/M4 | Passwort **nicht** in der Prozessliste (nur `-pwfile /dev/fd/N`). **B:** fd 0–2 = PTY, 3 = Passwort-Pipe (leer, Schreibende zu), danach nur plinks eigene (Signal-Pipe, Netz, Agent-Socket, TCP); TTY `??`. **A:** erbt fd 3–6 der App (B2), hat Steuerterminal | wie ohne Sandbox (B): nur fd 0–3 geerbt, Passwort nicht sichtbar, Umgebung nur `COLORTERM HOME LANG LOGNAME PUTTYDIR SSH_AUTH_SOCK TERM USER` |
| M6 | Schlüsseldatei direkt (`-i <gewählter Pfad>`) | (nicht gesondert gemessen; ohne Sandbox kein Zugriffsschutz) | **ok – entgegen B6:** plink hat die Datei gelesen („Server refused our key“) |
| M7 | Schlüssel-Kopie im App-Ordner | entfällt (M6 zeigt direkten Zugriff) | entfällt |
| M8 | `/dev/cu.*` öffnen | – | **ok** – plink hält `/dev/cu.Bluetooth-Incoming-Port` offen |
| M9 | Umgebung des Kindprozesses | **ok** – `HOME` = Benutzerordner | **ok** – `HOME`/`PUTTYDIR` im Container |
| M10 | OSC 52 (`printf '\033]52;c;?\a'` und Schreiben) | **A:** schreibt ohne Rückfrage, **sendet die Zwischenablage an den Server** (B3, mit Testtext gemessen). **B:** beides abgelehnt | **B:** Lesen abgelehnt |
| M11 | Bauzeiten, Größen, `otool -L`, `/Users/`-Suche | **ok** – PuTTY (plink, pscp, psftp, puttygen) in 12 s, nur `libSystem`, 0 Treffer `/Users/`; plink 1 074 168 Bytes, `plink -V` = 0.85 (`a3cce3a4`), identisch mit dem Vergleichs-Build; 5 Warnungen (1× `-Wreturn-type` in `arm_arch_queries.h`, 4× doppelte Linker-Bibliotheken). Prototyp: erster Bau 61 s, danach 1–4 s; 0 Treffer `/Users/` | – |

---

## 3. Sandbox-Empfehlung

**Empfehlung: Die App kommt in M1 ohne App Sandbox**, mit Hardened Runtime (wie jetzt). Leonard hat am 15.10.2026 zugestimmt; Plan Abschnitt 8, Punkt 7 ist entsprechend nachgeführt.

Gründe (gemessen):

1. **Terminal-Steuerung (B14).** Ein Hilfsprogramm in der Sandbox darf sein Terminal nicht umschalten. Damit kann plink weder den Rohmodus setzen noch die Anzeige bei Passwortabfragen abschalten – ein getipptes Passwort ist sichtbar. Ein Umweg (die App setzt die Modi über den Master) bringt `vim` zum Laufen, verlangt aber weitere Eingriffe: eigene Terminal-Modi für den Server (sonst fehlen CR), Sonderbehandlung von Return für plinks Abfragen (B17) und ein eigenes Umschalten für jede Passwortabfrage. Das hängt an plinks inneren Abläufen und kann mit jedem PuTTY-Update brechen.
2. **Netzwerk (B15).** Die Sandbox-App bräuchte zusätzlich das Server-Recht.
3. **Weg A fällt in der Sandbox doppelt aus** (keine Startgröße, kein Steuerterminal) – für Weg B irrelevant, aber ein Hinweis, wie eng die Sandbox an dieser Stelle ist.

Was in der Sandbox ging: Netzwerk (mit Server-Recht), Seriell, Schlüsselbund, Schlüsseldatei aus dem Öffnen-Dialog, Fenstergröße über den Master.

**Wann wieder prüfen:** nur wenn die App in den Mac App Store soll (dort Pflicht). Dann wäre der saubere Weg, die Terminal-Modi vollständig in der App zu verwalten oder statt plink eine eingebettete SSH-Bibliothek zu nutzen – das wäre ein eigener Meilenstein.

---

## 4. Vorschläge für den Plan (am 15.10.2026 von Leonard angenommen)

1. **Weg B statt `LocalProcessTerminalView`** (B2, B3, B4): `TerminalView` + `posix_spawn`, Slave in der App öffnen, Größe über den Master (B13), `SIGWINCH` selbst schicken, OSC 52 und Links abgelehnt. Erfüllt S1 (Passwort genau auf fd 3, keine Deskriptor-Lecks) und S11 von Anfang an.
2. **Sandbox in 8.7: „nein (vorerst)“** mit der Begründung aus Abschnitt 3.
3. **Terminaltyp über die Sitzungsdatei** (B11): Die App schreibt `TerminalType=xterm-256color` in die PuTTY-Sitzung bzw. `Default Settings` im eigenen `PUTTYDIR`. Dateien im `PUTTYDIR` mit `0600` anlegen (im Prototyp hatten `sshhostkeys` und `Default%20Settings` noch `0644`; der Ordner selbst war `0700`).
4. **„Press Return to begin session“** (B17) in M1 bewusst behandeln: Hinweis anzeigen oder `-no-antispoof` setzen.
5. **Passwort falsch** (B5): plink bricht ab → die App bietet „neu eingeben“ an und überschreibt den Schlüsselbund-Eintrag erst nach erfolgreicher Anmeldung.
6. **Bauen außerhalb von iCloud** (B16): Alle Bauergebnisse und signierten Pakete unter `~/Library/Caches/SSH-App-Build`.
7. **Schlüsselbund ohne Team-ID** (B9): In M3 entscheiden, ob gelegentliche Rückfragen nach einem Update hingenommen werden oder ein kostenloses Apple-Konto mit fester Signatur genutzt wird.
8. **Abbrechen ohne Steuerterminal** (B4): Ctrl-C wirkt bei plinks lokalen Abfragen nicht – eigene „Abbrechen“-Schaltfläche (beendet plink per Signal).
9. **Aus dem Prüfbericht für M1:** Passwort ohne Zwischenkopie in die Pipe schreiben (`writev` mit Passwort und `\n` getrennt) und die Schlüsselbund-Daten danach löschen; `master = -1` im Cancel-Handler setzen; `read` bei `EINTR`/`EAGAIN` wiederholen statt die Sitzung zu beenden; GPG-Prüfung auf den festen Fingerabdruck (`VALIDSIG 1A07DAC0…`) statt jeder gültigen Signatur; vor `git init` eine `.gitignore` mit `build/` und `Quellen/` anlegen (Logs unter `build/` enthalten lokale Pfade mit Benutzernamen).
10. **Bauwächter absichern** (Prüfbericht M3): Er führt aus, was in `build/m0/cmd.sh` steht – und der Ordner liegt im iCloud-synchronisierten Schreibtisch. Wenn er nicht gebraucht wird, das Fenster schließen; für M1 die Auftragsablage nach `~/Library/Caches/SSH-App-Build/` verlegen, Inhalt und SHA-256 jedes Skripts ins Log schreiben, Zeitlimit je Auftrag, Statusdatei atomar schreiben (`mv`).

---

## 5. Abweichungen und Hinweise

- Der Wegwerf-Prototyp ist ein Swift-Paket (`build/m0/Prototyp/Package.swift`) statt eines `.xcodeproj`; Swift-5-Sprachmodus nur im Prototyp. Das App-Projekt in M1 wird ein normales Xcode-Projekt.
- M6 wurde mit einem Wegwerf-Schlüssel gemessen, **ohne** `~/.ssh/authorized_keys` zu ändern. Der Schlüssel ist gelöscht.
- Werkzeug-Hinweis (nicht App): Die Dateiübertragung auf den Mac meldete zweimal „geschrieben“, obwohl die alte Fassung liegen blieb. Seitdem wird nach jeder Übertragung die Prüfsumme verglichen.
- Aufgeräumt (15.10.2026, nach Leonards Zustimmung): Schlüsselbund-Testeintrag „SSH-App-M0-Test“ gelöscht (geprüft mit `security find-generic-password`), Wegwerf-Schlüssel gelöscht, Prototyp-Pakete und SwiftPM-Bauordner unter `~/Library/Caches/SSH-App-Build/` gelöscht (der Ordner selbst bleibt für M1), PuTTY-Ordner `~/Library/Application Support/SSH-App-Prototyp/` gelöscht, Inhalt des Sandbox-Containers gelöscht. Übrig ist nur die von macOS geschützte Verwaltungsdatei des Containers (32 KB, `~/Library/Containers/<Bundle-ID>.sandbox/`) – lässt sich nur im Finder in den Papierkorb legen.
