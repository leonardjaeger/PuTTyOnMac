# M1 – Prüfliste

**Stand:** 15.10.2026 · **Meilenstein:** M1 Fundament · **Version:** 0.1.0 (Build 1) · **Status:** abgenommen am 15.10.2026 („passt alles“; Commit, Tag `m1`, Plan nachgeführt)

---

## 1. Umfang laut Plan (Abschnitt 5, M1) und Prompt M1

| # | Punkt | Stand | Nachweis |
|---|---|---|---|
| 1 | Xcode-Projekt: App, Kern-Paket, Tests; Swift 6; Icon-Platzhalter | ✅ | `SSHApp.xcodeproj` (App `SSH-App`, Modul `SSHApp`), `SSHAppCore` (Swift-Paket), `SSHAppCoreTests`, `SSHAppTests`; Platzhalter-Icon „>_“ |
| 2 | `Scripts/build-putty.sh`: Prüfsumme fest, ohne GTK, `-ffile-prefix-map`, nach `Contents/Helpers`, signiert mit Hardened Runtime, Ein-/Ausgabedateien für Xcode | ✅ | plink, pscp, psftp, puttygen; nur `libSystem`; 0 Treffer `/Users/` (Debug und Release); Stempel aus Quelle + Patches + Skript |
| 3 | GPG-Prüfung auf festen Fingerabdruck bei Versionswechsel (S7) | ✅ mit Einschränkung | Modus `--gpg-pruefen` (wertet `VALIDSIG` aus); auf dem Mac fehlt `gpg`, daher nicht Teil jedes Baus |
| 4 | Schnellverbindung „benutzer@host:port“ + Protokollwahl | ✅ | `ConnectForm`, `Endpoint`; SSH, Telnet, Raw |
| 5 | Native Tabs, ⌘T mit Verbindungsauswahl | ✅ | neuer Tab zeigt die Schnellverbindung, **vorbelegt mit Adresse und Protokoll des aktiven Tabs** (geprüft) |
| 6 | Fenstertitel = Host | ✅ | Titel = Adresse (z. B. `test@server.example:2222`) |
| 7 | Rückfrage beim Schließen einer aktiven Verbindung | ✅ | Blatt „Verbindung zu … trennen?“ – „Trennen“ / „Abbrechen“; beim Beenden der App Rückfrage mit Anzahl |
| 8 | Meldung bei Verbindungsende mit „Erneut verbinden“ | ✅ | Leiste unter der Titelleiste mit Grund (Exit-Code/Signal/„getrennt“) und Knopf, ⌘R |
| 9 | `PlinkCommand` und `SessionFile` im Kern mit Tests (S3, S4) | ✅ | nur `-load <Name>`; feste Umgebung; CR/LF/NUL nie geschrieben |
| 10 | Grundsatz-Tests: Kern ohne AppKit; `-`-Hosts/Steuerzeichen abgelehnt; kein `-pw` im ganzen Code | ✅ | `ArchitectureTests` (dazu: keine `/Users/`, kein `#file`, IPv4 nur Beispielbereich, jede Log-Interpolation mit `privacy:`); Übungsbruch: 2 Fehler wie erwartet, zurückgenommen |
| 11 | `LICENSE` (MIT, Leonards Name), `THIRD_PARTY_NOTICES.md` (PuTTY, SwiftTerm), `.gitignore` (lokale Testsitzungen) | ✅ | Patch in den Hinweisen erwähnt; `Lokal/` ausgenommen |
| 12 | `docs/Stand.md` | ✅ | neu gefasst (Version, Tests, Bauwächter, Entscheidungen) |
| 13 | M0-Vorgabe: `posix_spawn` mit `CLOEXEC_DEFAULT`, `SETSID`, Slave `O_NOCTTY`, `TIOCSWINSZ`, eigenes `SIGWINCH`; OSC 52 und Links abgelehnt | ✅ | `TerminalProcess`; Test: Kind sieht nur 0/1/2 |
| 14 | M0-Vorgabe: Terminaltyp über Sitzungsdatei, Dateien `0600` | ✅ | `TerminalType=xterm-256color`; umask 077 beim Start; Ordner 0700 |
| 15 | M0-Vorgabe: „Press Return to begin session“ bewusst entscheiden | ✅ Entscheidung | **bleibt an** (kein `-no-antispoof`), siehe Abschnitt 5 |
| 16 | M0-Vorgabe: eigener Abbrechen-Weg | ✅ | Verbindung › Trennen (⌘.) → `SIGHUP`, Meldung „Verbindung getrennt.“ |
| 17 | M0-Vorgabe: robuste E/A (`master = -1`, `EINTR`/`EAGAIN`) | ✅ | Lesen und Schreiben nicht blockierend, Wiederholung bei `EINTR` auch beim Restlesen |
| 18 | M0-Vorgabe: `-pwfile` mit `writev`, 2FA-Angebot | ➖ M3 | M1 übergibt keine Passwörter; im Plan bei M3 nachtragen |
| 19 | M0-Vorgabe: Bauwächter absichern (Ablage außerhalb iCloud, SHA-256 im Log, Zeitlimit, Status atomar) | ✅ | dazu: Aufträge atomar angelegt, Namensprüfung, stdin `/dev/null` |
| 20 | Prüfliste, Skill-Protokoll, Sicherheits-Audit, ponytail-review, code-review | ✅ | dieses Dokument |

## 2. So prüfst du

Vorher: Bauwächter **neu starten** (`watch.sh` wurde geändert). Für die Anmeldung „Entfernte Anmeldung“ in den Systemeinstellungen einschalten (deine Entscheidung; ich habe sie nicht geändert) – oder den Testserver nutzen (`bash build/m1/testserver.sh start`, dann `test@127.0.0.1:2222` … siehe Stand.md).

- [x] Xcode: `SSHApp.xcodeproj` öffnen, beim SwiftTerm-Plugin einmal „Trust & Enable“, **⌘U → alle Tests grün** (39 Kern + 14 App)
- [x] ⌘R, Menüleiste: SSH-App · Ablage · Bearbeiten · Darstellung · Verbindung · Fenster · Hilfe
- [x] Schnellverbindung `<dein Benutzer>@localhost`, SSH → plink fragt nach dem Hostschlüssel (Text im Terminal) → `y` → Passwort → „Press Return to begin session“ → Return → Prompt; Titel = Adresse
- [x] `top`/`vim`, Fenstergröße ändern, Umlaute tippen
- [x] **⌘T** → neuer Tab, Adresse ist vorbelegt → Return → zweite Verbindung **ohne** zweite Hostschlüssel-Frage
- [x] Tab mit laufender Verbindung schließen (⌘W) → Rückfrage; „Abbrechen“ lässt sie laufen
- [x] `exit` → Leiste „Verbindung beendet.“ mit „Erneut verbinden“ (⌘R verbindet neu)
- [x] Während der Passwortabfrage Verbindung › Trennen (⌘.) → „Verbindung getrennt.“
- [x] Als Adresse `-proxycmd x` → Fehlermeldung unter dem Feld, keine Verbindung
- [x] App mit laufender Verbindung beenden (⌘Q) → Rückfrage

## 3. Eigene Prüfung (Tests, Oberfläche, Messungen)

- **Tests:** Kern 39 (5 Suiten), App 14 – alle grün (Auftrag `m1t14`); 0 Compiler-Warnungen im eigenen Code.
- **Regressionstests zu gefundenen Fehlern:** abgewiesene Verbindung (PuTTY-Patch, ohne Patch hängt der Test), „Signal 1“ nach Trennen, nicht blockierendes Senden (mit altem Code rot: 0,89 s > 0,5 s, mit neuem grün), Übrigbleibsel `.schreiben-*`, Menüreihenfolge, Zeilenumbruch am Ende einer eingefügten Adresse.
- **Oberfläche (Computer-Steuerung, Debug-Build):** Formular mit Platzhalter `benutzer@server.example:22`, Fehlermeldung mit Symbol und Text (nicht nur Farbe), Terminal mit Leiste und „Erneut verbinden“, Tabs mit vorbelegter Adresse, Menüreihenfolge, Beenden ohne Rückfrage bei beendeter Verbindung. Anmeldung mit Hostschlüssel-Abfrage und Schlüssel-Anmeldung vorher gegen den Testserver (127.0.0.1:2222). Passwort-Anmeldung an `localhost` habe ich nicht gemacht (Passwort tippst nur du).
- **Danach aufgeräumt:** App beendet, Sitzungsordner leer, Ordner `0700`, Testserver gelöscht.
- **S14:** `strings` auf App und Helfer (Debug und Release): 0 Treffer `/Users/`; der Benutzername kommt nur in der erlaubten Bundle-ID vor.
- **Bauzeit:** `docs/build-timing.md` (sauber 15 s, nach einer Änderung 7 s, keine langsamen Funktionen).
- **Größe:** Debug-App 14 MB; plink, pscp, psftp je ca. 1 MB, puttygen 0,4 MB.

## 4. Sicherheits-Audit (vibe-security, Prüfer-Agent, nachgeprüft)

**Nicht zutreffend:** Datenbanken/RLS, Web-Authentifizierung, Rate-Limits, Zahlungen, Mobile, KI-Schlüssel, HTTP-Header/CORS. **Geheimnisse:** keine im Code, in Skripten oder im Repo.

### Kritisch / Hoch
Keine Befunde.

### Mittel

**M1 · `SSHApp/TerminalProcess.swift` – blockierendes Schreiben im Hauptthread (DoS) – behoben**
Ein Server, der sein SSH-Fenster nicht öffnet und viele Terminal-Abfragen (`ESC[6n`) schickt, oder ein großes Einfügen in eine Sitzung, die nicht liest, ließ `write` blockieren: die ganze App mit allen Tabs fror ein.
```text
Vorher:  write(master, …) in einer Schleife, Wiederholung bei EAGAIN (blockierender Master)
Nachher: Master O_NONBLOCK; Rest in `pending` (höchstens 4 MiB, darüber verworfen),
         Nachlieferung über DispatchSourceWrite auf eigener dup-Nummer; Test 1 MB an ein
         nicht lesendes Programm kehrt sofort zurück und kommt vollständig an
```

**M2 · Name des Entwicklers in Bundle-ID und Log-Subsystem (S12/S14) – bewusst so**
`de.leonardjaeger.sshapp` steht in Binary, Info.plist und Systemprotokoll. Der Prompt M1 erlaubt das ausdrücklich (Muster `de.leonardjaeger.<arbeitstitel>`, nur der Autorenname). Umbenennung in M7 in einem Schritt.

### Niedrig

| Befund | Stand |
|---|---|
| `build-putty.sh`: Stempel ohne das Skript selbst → geänderte Flags bauen nicht neu | behoben (Skript-Hash im Stempel; `nullglob` für Patches) |
| `watch.sh`: Auftrag erbt das Terminal als stdin (SIGTTIN hält ihn an) | behoben (`< /dev/null`) |
| `watch.sh`: Wächter-`sleep` lief nach Auftragsende weiter | behoben (ganze Gruppe beenden) |
| `go.sh`: Auftrag nicht atomar, kann leer ankommen | behoben (Zwischendatei + `mv`, Namensprüfung) |
| `PuTTYDirectory`: Absturz zwischen `open` und `rename` lässt `.schreiben-*` mit Server/Benutzer liegen | behoben (Aufräumen beim Start/Ende) + Test |
| `testserver.sh stop`: beendet gespeicherte PID ohne Prüfung | behoben (nur wenn noch sshd/ssh-agent) |
| GPG-Prüfung nur von Hand | offen, beim PuTTY-Update verpflichtend (`--gpg-pruefen`) |
| Modus `skript` führt `build/skript.sh` aus | gewollt; Hash und Inhalt im Log, Name und Modus geprüft |

**Geprüft und unauffällig:** Prozessstart (Kind erbt nur 0/1/2, getestet; `SETSID`; Signale zurückgesetzt; PID nach `waitpid` gelöscht), Prüfregeln (ASCII-Server oder IPv6 mit Zone, Cc/Cf/Zl/Zp, Leerraum inkl. NBSP, führendes „-“; Umbrüche nur am Rand entfernt), Sitzungsdatei (kein CR/LF/NUL, Dateinamen wie PuTTYs `mungestr`, Pfad-Ausbruch getestet), `PlinkCommand` (nur `-load`, Umgebung als feste Liste ohne `DYLD_*`/`XDG_*`), S1 (kein `-pw`, Test), S5 (Hostschlüssel fragt plink, kein `-batch`), S9 (Host mit `.private(mask: .hash)`), S11 (OSC 52, Links, Server-Fenstertitel verworfen), Hardened Runtime für App und Helfer.

## 5. Entscheidungen und Abweichungen (bitte bestätigen)

1. **Echtheitsprüfung von plink bleibt an.** Nach Abfragen erscheint „Press Return to begin session“ (englisch, von plink). Damit kann ein Server keine falsche Passwortabfrage vortäuschen. Kein eigener Hinweis der App.
2. **PuTTY-Patch** (eine Zeile, `POLLHUP` beim Verbinden): ohne ihn hängt plink bei abgewiesener Verbindung mit 100 % CPU (macOS liefert nur `POLLHUP`). Mit deiner Zustimmung eingebaut. Empfehlung: an das PuTTY-Team melden.
3. **Telnet und Raw** sind schon wählbar (Plan: M5). Raw ist getestet, Telnet nicht. Alternative: bis M5 ausblenden.
4. **Trennen auf ⌘.** (wie „Abbrechen“ in macOS). Menü „Verbindung“ steht zwischen „Darstellung“ und „Fenster“.
5. **Xcode-Plugin:** SwiftTerm-Plugin braucht einmal „Trust & Enable“; der Bauwächter überspringt die Abfrage.
6. **Anmeldetest** gegen einen eigenen sshd auf 127.0.0.1:2222 mit Schlüssel statt „Entfernte Anmeldung“ – dort endet `exit` mit Exit-Code 1 (Eigenheit eines sshd ohne Root); mit `localhost:22` prüfst du es selbst.
7. **Neuer Tab übernimmt die Adresse** des aktiven Tabs (so ist „zweiter Tab mit derselben Verbindung“ ein Return).
8. **Eingefügte Adresse mit Zeilenumbruch am Ende** wird angenommen (Umbruch am Rand entfernt, im Inneren weiter abgelehnt).

## 6. Code-Review (mattpocock code-review, seit `m0`)

### Standards (Richtlinien, sinngemäß)
- **Behoben:** Menüreihenfolge (3.4 Regel 5), Phase „PuTTY-Werkzeuge bauen“ hat den Patch-Ordner als Eingabe (3.1 Regel 3), App-Tests nutzen eigene PuTTY-Ordner statt Application Support (3.9 Regel 3), `docs/build-timing.md` (3.1 Regel 4), `pid` privat, doppelte Leseschleife zusammengeführt, Portbereich nur noch an einer Stelle, `"sessions"` nur noch einmal, Test-Sockets in einer Hilfsfunktion.
- **Bewusst gelassen (Ermessen):** `runModal` beim Beenden (mehrere Fenster, kein Blatt möglich); `DispatchSource` statt Swift-Concurrency für die PTY-Ereignisse (es gibt keinen async-Weg für kqueue auf einem Deskriptor); `ConnectionWindowController` bündelt Formular, Terminal, Leiste und Rückfragen eines Tabs (ca. 190 Zeilen; Aufteilen erst, wenn M2/M4 mehr hineinbringen); `Connection` reicht einiges an `TerminalProcess` durch (trennt aber Sitzungsdatei und Prozess); `columns/rows` als Paar; `waitpid`-Status als `Int32`; `xterm-256color` in Kern und Umgebung je einmal; keine Leistungstests (M4 mit `apple-skills:performance`); `ConnectForm.connect` bleibt intern (eigener `init`).

### Spec (Plan M1)
- Keine falsch umgesetzten Anforderungen. Prüfliste, Stand und ⌘T-Vorbelegung nachgezogen; `EINTR` beim Restlesen behoben.
- **Für den Plan nach Abnahme:** bei M3 `writev` und das 2FA-Angebot ausdrücklich nachtragen; bei M5 vermerken, dass Telnet/Raw schon wählbar sind.
- Release-Builds: Symbole der App selbst werden erst mit der Weitergabe (M7, `release-review`) entfernt; der `strings`-Test ist schon sauber.

## 7. Skill-Protokoll

Ehrlicher Hinweis: Mitten in M1 wurde der Chatverlauf wegen seiner Länge zusammengefasst. Danach war nur noch für **ponytail-review, code-review und computer-use** nachweisbar, dass sie mit dem Skill-Werkzeug geladen waren. Die übrigen Pflicht-Skills habe ich deshalb in der Abschlussphase (nach der Umsetzung, vor dieser Prüfliste) **erneut geladen** und den Stand damit geprüft. Ob sie vor der Umsetzung geladen waren, kann ich nicht mehr belegen.

| Skill | Wofür | Umgesetzt | Bewusst nicht |
|---|---|---|---|
| `anthropic-skills:ponytail` | kleinste vollständige Lösung | keine Abhängigkeit außer SwiftTerm; Schnellverbindung ohne Sitzungsverwaltung; Plattform (posix_spawn, os.Logger, NSWindow-Tabs) | – |
| `anthropic-skills:vibe-security` | S1–S14, Audit | Abschnitt 4; Vertrauensgrenzen (Adresse, Sitzungsdatei, Prozessstart, Server-Ausgabe) | Web-Abschnitte nicht zutreffend |
| `anthropic-skills:ponytail-review` | Prüfer-Agent | Befunde 1–9 behoben bis auf GPG-Automatik | Diagnoseskript `build/m1/cmd.sh` bleibt bis zur Abnahme (Nachvollziehbarkeit) |
| `mattpocock-skills:code-review` | Standards + Spec seit `m0` | Abschnitt 6 | siehe „Bewusst gelassen“ |
| `anthropic-skills:computer-use` | eigene Oberflächenprüfung | Hintergrund-Steuerung der SSH-App, Menü über Menüleiste | keine Passworteingabe |
| `apple-skills:swift` | Swift 6, MainActor-Grenzen | MainActor als Standard; `MainActor.assumeIsolated` in den Ereignisquellen; Test-Hilfen ohne Isolationswarnungen | – |
| `apple-skills:macos` | AppKit/SwiftUI-Brücke, HIG | `NSHostingView` mit `sizingOptions = []`, native Tabs, Blatt-Rückfrage | `macos-tahoe-apis` (Richtlinien 7.4) |
| `apple-skills:testing` + `mattpocock-skills:tdd` | Test zuerst, Grundsatz-Tests | Kern-Bausteine über ihre Schnittstelle getestet; Fehlerbehebungen mit rotem Test zuerst (Senden: am alten Code rot nachgewiesen) | keine Mutationstests |
| `mattpocock-skills:codebase-design` | tiefe Kern-Module | `SessionFile.quickConnect`, `PlinkCommand`, `PuTTYDirectory` mit schmaler Schnittstelle; Testnaht für den PuTTY-Ordner an `Connection` | kein Protokoll für eine zweite Prozess-Art (nur ein Adapter) |
| `mattpocock-skills:domain-modeling` | Begriffe | `docs/CONTEXT.md` (Sitzung, Schnellverbindung, Adresse, Verbindung, Trennen, Abfrage …) | kein ADR (Entscheidungen leicht umkehrbar) |
| `apple-skills:swiftui` + `anthropic-skills:swiftui-pro` | Formular | `Form(.grouped)`, `Label` mit Symbol für Fehler, `Button(_:action:)`, `@State private`, Vorbelegung über `State(initialValue:)` | Hinweis „kein GCD“ nicht übernommen (PTY braucht Deskriptor-Ereignisse) |
| `apple-skills:design` | SF Symbols, UX-Texte | Rückfrage besteht den Kurztest (Titel + Knöpfe sagen alles), „Trennen“ destruktiv; `bolt.horizontal.circle`, `exclamationmark.triangle` | Liquid Glass nur über Standardkomponenten |
| `apple-skills:generators` (`logging-setup`) | Logger mit Datenschutz | `AppLog` (Kategorien connection/app), jede Interpolation mit `privacy:` (Test) | Subsystem als Konstante statt aus der Bundle-ID gelesen (eine Stelle) |
| `mattpocock-skills:research` | PuTTY-Fakten | `docs/M1-Recherche.md` (Quellcode 0.85) | – |
| `mattpocock-skills:diagnosing-bugs` + `tdd-bug-fix` | Fehler | plink-Hänger: Rückkopplung (Test + Mini-C-Programm) → Ursache `POLLHUP` → Patch + Regressionstest; „Signal 1“; blockierendes Senden | – |

## 8. Geänderte und neue Dateien

Neu: `SSHApp.xcodeproj`, `SSHApp/` (10 Swift-Dateien, Asset-Katalog), `SSHAppCore/` (Paket, 6 Quellen, 5 Testdateien), `SSHAppTests/` (3), `Config/Info.plist`, `Scripts/build-putty.sh`, `Scripts/putty-patches/0001-…patch`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `docs/CONTEXT.md`, `docs/M1-Recherche.md`, `docs/M1-Pruefliste.md`, `docs/build-timing.md`, `build/m1/` (Hilfsskripte). Geändert: `.gitignore`, `Scripts/build.sh`, `Scripts/go.sh`, `Scripts/watch.sh`, `build/skript.sh`, `docs/Stand.md`.
Umfang: App 749 Zeilen, Kern 380, Tests 675.
