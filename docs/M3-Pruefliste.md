# M3 – Schlüssel & Anmeldung: Prüfliste

**Stand:** 19.10.2026 · Version 0.1.1 (Build 2) · Grundlage: Tag `m2` · **abgenommen am 19.10.2026** („passt alles, Programm läuft“) · Commit „M3 Schlüssel & Anmeldung“, Tag `m3`

Fakten und Messungen: `docs/M3-Recherche.md`. Alle Beispiele nur mit Platzhaltern (S14); Wegwerf-Schlüssel und
-Server lagen nur im Cache-Ordner.

## 1. Umsetzung

| Nr. | Punkt | Status | Nachweis |
|---|---|---|---|
| 1 | **Fenster „Schlüssel“** (Seitenleiste unten, Fenster-Menü, Hilfe › „Anmeldung mit Schlüssel und Agent“): neuen Schlüssel erzeugen – Ed25519 Standard, ECDSA P-256, RSA 4096 –, Kommentar, Passphrase zweimal, Sichern-Dialog | ✅ | `KeysView`, `KeysModel`, `PuttygenCommand` (Kern); puttygen über `HelperProcess` (stdin `/dev/null`, Passphrase nur über Pipe ab fd 3); Datei `0600`, `aes256-cbc` (`HelperProcessTests`) |
| 2 | Schlüsseldatei öffnen: Typ, Kommentar, **Fingerabdruck SHA256** und öffentlicher Schlüssel, je mit Kopierknopf; Passphrase wird nur bei Bedarf erfragt (Sheet), falsche Passphrase mit Hinweis | ✅ | `LoadedKeyDetails`, `PassphrasePrompt`; Fehlertexte von puttygen im Kern gelesen (`PuttygenCommandTests`) |
| 3 | **Umwandeln** `.ppk` ↔ OpenSSH („Als PuTTY-Schlüssel (.ppk) sichern …“, „Als OpenSSH-Schlüssel sichern …“), Passphrase bleibt erhalten | ✅ | Gegenprobe mit `ssh-keygen -y` (gleicher Fingerabdruck); Test `testGenerateReadAndConvertWithPassphrase` |
| 4 | **Auf den Server übertragen** als Anleitung: Befehl zum Kopieren, kein automatisches Schreiben | ✅ | `mkdir -p ~/.ssh && chmod 700 ~/.ssh && printf '\n%s\n' '<Schlüssel>' >> ~/.ssh/authorized_keys && chmod 600 …`; `printf` statt `echo`, eigene Zeile auch ohne Zeilenende am Dateiende (Befund des Prüfers); Test führt den Befehl mit eigenem HOME im Testordner aus (`KeysModelTests`) |
| 5 | **Agent:** plink nutzt `SSH_AUTH_SOCK` (seit M1); im Fenster „Schlüssel“ fester Hinweis mit `ssh-add --apple-use-keychain …` und `ssh-add --apple-load-keychain`, bei geöffneter OpenSSH-Datei mit deren Pfad | ✅ | `KeysView` Abschnitt „Agent“; keine eigene Pageant-Oberfläche |
| 6 | **Schlüsseldatei je Sitzung** im Editor (Abschnitt „Anmeldung“): „Wählen …“ nimmt nur PuTTY-Schlüssel (Kopf `PuTTY-User-Key-File-`), sonst Hinweis auf das Fenster „Schlüssel“; „Keine Schlüsseldatei“ | ✅ | `SessionAuthenticationSection`, `SessionFile.setPublicKeyFile` (absoluter Pfad, keine Zeilenumbrüche, S4) |
| 7 | **Passwort im Schlüsselbund** (freiwillig, je Sitzung): „Im Schlüsselbund sichern …“ im Editor, ändern, löschen; gebunden an `benutzer@server:port`; nicht bei Proxy, Telnet/Raw, ohne Benutzer und mit festen Hostschlüsseln (`SSHManualHostKeys`) | ✅ | `PasswordStore` (Anmelde-Schlüsselbund, nicht synchronisiert, Dienst `de.leonardjaeger.tunnelterminal.passwort`, Konto = Sitzungsname), `SavePasswordSheet`, `SessionFile.passwordTarget`; Tests `PasswordStoreTests`, `PasswordTargetTests`, `PlinkAddressTests` |
| 8 | **Übergabe an plink nur über Pipe** (`-load <Sitzung> -pwfile /dev/fd/3`), mit `writev` ohne Zwischenkopie, Pipe als einziger weiterer Deskriptor | ✅ | `TerminalProcess.start(secret:)`, `pipe(holding:)`; Tests: fd 3 kommt an, fd 4+ nicht; Passwort nicht in Argumenten/Umgebung; zu langes Passwort abgelehnt; end-to-end mit echtem plink (`testStoredPasswordGoesToPlinkThroughPipe`) |
| 9 | Passwort gehört zu einem anderen Ziel (Server/Benutzer/Port geändert, Import) → nicht verwendet, gedimmter Hinweis im Terminal | ✅ | `testPasswordForOtherTargetIsNotUsed` |
| 10 | **„Configured password was not accepted“** (2FA, falsches Passwort): Endtext „Das gespeicherte Passwort wurde nicht angenommen.“ und Knopf „Ohne gespeichertes Passwort verbinden“ – nur wenn plink danach mit Fehler endet und man nicht selbst getrennt hat | ✅ | `RejectedPasswordWatch` (auch über zwei Lese-Blöcke, Test für jede Teilungsstelle), `EndedBanner` |
| 11 | Sitzung **umbenennen** → Schlüsselbund-Eintrag zieht mit; **löschen** → Eintrag weg | ✅ | `SessionLibrary` mit `passwords`; Tests in `SessionLibraryTests` |
| 12 | **Liste „Bekannte Hostschlüssel“** (Seitenleiste unten, Fenster-Menü, Inspektor): Server, Port, Typ, Fingerabdruck; Entfernen mit Rückfrage (auch ⌫), Datei atomar mit `0600`, Verweise werden weder gelesen noch überschrieben | ✅ | `KnownHostKeys` (Kern, Fingerabdruck SHA256 aus PuTTYs Format, echte Testvektoren für Ed25519/ECDSA/RSA), `PuTTYDirectory.removeKnownHostKeys`, `KnownHostsView`; Fingerabdruck-Spalte jetzt ungekürzt (Fenster ≥ 760 pt) |
| 13 | **Inspektor „Hostschlüssel“**: Typ und Fingerabdruck, „Bekannt – plink warnt, wenn er sich ändert“ bzw. „Noch nicht bekannt“ mit Hinweis; aktualisiert sich, sobald man plinks Abfrage bestätigt; Knopf „Bekannte Hostschlüssel“ | ✅ | `HostKeyInspectorSection`; Server/Port genau wie plink (`LogicalHostName`, `benutzer@`, `:…`, IPv6-Klammern – `SessionFile.hostKeyServer`) |
| 14 | Inspektor „Verbindung“, Anmeldung: „Schlüsseldatei „x.ppk““, „Agent, sonst Passwort“ bzw. „… Passwort aus dem Schlüsselbund“, wenn plink es wirklich bekommt | ✅ | `ConnectionSummary.endsWithPassword`, `info.hasStoredPassword = usesStoredPassword` nach dem Start |
| 15 | **GSSAPI abgeschaltet** (`-DPUTTY_GSSAPI=OFF`); Bau bricht ab, falls `libgssapi` wieder auftaucht; `GSSCustom` bleibt als Hinweis („Diese App lädt sie nicht, andere PuTTY-Installationen schon.“) | ✅ | plink/puttygen: „Build option: NO_GSSAPI“, nur `libSystem`, 0× `libgssapi` (übrig sind nur Namen der GSS-Schlüsseltausch-Verfahren in PuTTYs Tabellen); `SessionWarningTests` |
| 16 | **AccentColor** Bernstein `#F2A33A` | ✅ | `Assets.xcassets/AccentColor`, beide App-Konfigurationen; Kontrast siehe Entscheidung E1 |
| 17 | **Port wie plink** (Fehlerfund): `PortNumber` gilt nur mit bekanntem `Protocol`, sonst 22; `setPortNumber` ergänzt `Protocol=ssh` | ✅ | Bug-Test zuerst, `SessionSettingsTests`; betraf Inspektor, S4-Anzeige, Passwort-Bindung, Hostschlüssel |
| 18 | `build/skript.sh` auf `build/m3/` (`schritt.txt`: „<skript> <schritt>“, Name geprüft) | ✅ | `build/m3/machbarkeit.sh`, `probe.sh`, `ui.sh` |
| 19 | Grundsatz-Test S1: Geheimnis-Wörter („passw“, „passphrase“, „secret“, „geheim“) nie in einer Zeile mit Protokoll (`Logger`, `print`, `NSLog`), `UserDefaults`/`@AppStorage`/`@SceneStorage` oder Dateischreiben; `SecItem…` nur in `PasswordStore.swift`; kein `-pw` | ✅ | `ArchitectureTests.secretsStayInKeychain` |

**Tests:** 131 Kern (16 Suiten) + 65 App (8 Klassen), alle grün, ohne Compiler-Warnungen (Läufe `m3k13`, `m3t9`).

## 2. So prüfst du (du selbst)

Die App läuft als Debug-Build. Im PuTTY-Ordner liegt die Testsitzung „M3-Test“ (127.0.0.1:2222, eigener Testserver
im Cache, Schlüssel `test.ppk` im Cache) – die räume ich nach deiner Prüfung mit `ui stop` weg.

**Am Mac (`localhost`)**
- [ ] Fenster „Schlüssel“ (unten in der Seitenleiste): Ed25519 erzeugen, mit Passphrase, nach `~/.ssh/` sichern → Fingerabdruck erscheint
- [ ] „Befehl kopieren“, in Terminal.app ausführen (trägt den Schlüssel in **deine** `~/.ssh/authorized_keys` ein) → Sitzung zu `localhost` anlegen, im Editor „Anmeldung › Wählen …“ die `.ppk` → Verbinden: plink fragt nur nach der Passphrase des Schlüssels, nicht nach dem Kontopasswort
- [ ] „Als OpenSSH-Schlüssel sichern …“, dann in Terminal.app `ssh -i <datei> localhost` → Anmeldung mit derselben Passphrase
- [ ] Optional Agent: `ssh-add --apple-use-keychain <OpenSSH-Datei>`, in der Sitzung „Keine Schlüsseldatei“ → Anmeldung ohne Frage

**Heimserver (nur im Heimnetz, S13)** – ich ändere dort nichts; du führst aus:
- [ ] In der App eine Sitzung „Heimserver“ (hast du schon) mit deinem Benutzer; einmal mit Passwort verbinden, dann im Terminal den kopierten Befehl aus dem Fenster „Schlüssel“ einfügen → trennen, Schlüsseldatei in der Sitzung wählen, verbinden → ohne Kontopasswort
- [ ] Zweite Sitzung ohne Schlüsseldatei: Editor › Anmeldung › „Im Schlüsselbund sichern …“, Passwort eingeben → Verbinden ohne Abfrage; Inspektor zeigt „… Passwort aus dem Schlüsselbund“
- [ ] Schlüsselbundverwaltung öffnen, nach „TunnelTerminal“ suchen → Eintrag „TunnelTerminal: <Sitzung>“ ist da; macOS fragt beim ersten Zugriff nach jedem neuen Bau einmal („Immer erlauben“, siehe Abweichung A4)
- [ ] Falsches Passwort sichern → „Das gespeicherte Passwort wurde nicht angenommen.“ mit „Ohne gespeichertes Passwort verbinden“ → plink fragt
- [ ] Sitzung umbenennen → Passwort geht weiter; Sitzung löschen → Eintrag in der Schlüsselbundverwaltung weg

**Hostschlüssel**
- [ ] Fenster „Bekannte Hostschlüssel“: Eintrag auswählen, „Entfernen …“, bestätigen → beim nächsten Verbinden fragt plink wieder; Inspektor zeigt bis zur Bestätigung „Noch nicht bekannt“, danach „Bekannt“
- [ ] Hell und dunkel: Bernstein-Akzent (Auswahl, Standardknopf) gut lesbar? → Entscheidung E1

- [ ] In Xcode ⌘U: alle Tests grün (beim ersten Lauf fragt macOS evtl. nach dem Schlüsselbund-Zugriff des Test-Hosts)

## 3. Von mir geprüft (Oberfläche, per Klick)

- Hauptfenster: unten in der Seitenleiste „Schlüssel“ und „Bekannte Hostschlüssel“; beide Fenster öffnen sich (je eines für die App), Liste anfangs leer mit Erklärung.
- „M3-Test“ verbunden: plink zeigte `SHA256:ITJXYb3S…` – gleich wie `ssh-keygen -lf` des Testservers; Inspektor „Noch nicht bekannt“. Nach deinem „y“ sprang der Inspektor auf „Bekannt“ mit ED25519 und demselben Fingerabdruck (die erste Verbindung brach danach mit „Connection reset by peer“ ab – der Testserver hatte die Anmeldezeit überschritten, während die Abfrage offen war).
- Mit `test.ppk` in der Sitzung (neuer Build): „Access granted“ ohne Abfrage; Inspektor Anmeldung „Schlüsseldatei „test.ppk““, Hostschlüssel „Bekannt“.
- Fenster „Bekannte Hostschlüssel“: Zeile 127.0.0.1 · 2222 · ED25519 · Fingerabdruck; Auswahl + „Entfernen …“ zeigt die Rückfrage „Hostschlüssel entfernen?“ mit Warntext. **Bestätigen konnte ich nicht mehr:** Der Bildschirm war gesperrt bzw. in einem anderen Space, Klicks kamen nicht an (Datei unverändert, 1 Zeile). Diesen Punkt bitte selbst prüfen (Abschnitt 2). Danach habe ich die App mit dem neuesten Build neu gestartet (Testserver und „M3-Test“ laufen weiter).
- Tippen in der App ist für mich nicht freigegeben – Passphrase- und Passwortfelder habe ich nicht bedient; das decken die App-Tests mit echtem puttygen/plink ab.

## 4. Messwerte

| Messung | Wert |
|---|---|
| Debug-App | 17 MB; plink und puttygen nur an `libSystem` |
| puttygen Ed25519 / ECDSA / RSA 4096 erzeugen | < 1 s / < 1 s / ca. 1 s |
| Datenschutz-Schlüsselbund (ad-hoc signiert) | `-34018` errSecMissingEntitlement (Test prüft das) |
| plink schreibt `sshhostkeys` ohne umask | `0644`; in der App `0600` |
| Port ohne `Protocol` | plink verbindet auf 22, egal was `PortNumber` sagt |

## 5. Abweichungen vom Plan und Entscheidungen

| Nr. | Punkt | Vorschlag |
|---|---|---|
| A1 | Plan: Passwort „nach erfolgreicher Anmeldung nur auf Nachfrage“ speichern. Die App erkennt eine erfolgreiche Anmeldung nicht, ohne die Ausgabe mitzulesen (S2) und ohne das getippte Passwort abzufangen. **Umgesetzt:** freiwillig im Editor („Im Schlüsselbund sichern …“) | so lassen |
| A2 | Das Passwort aus dem Schlüsselbund liegt als unveränderliches `CFData` vor und lässt sich nicht überschreiben, nur freigeben (direkt nach dem Start). Ehrlich als `shortcut:` im Code vermerkt | in der Härtung prüfen |
| A3 | ⌘Z nach dem Löschen einer Sitzung bringt die Sitzung zurück, aber **nicht** das Passwort (das müsste die App sonst im Speicher halten) | so lassen |
| A4 | Anmelde-Schlüsselbund statt Datenschutz-Schlüsselbund (ohne Entwickler-Team nicht nutzbar); nach jedem neuen Bau fragt macOS einmal nach dem Zugriff | so lassen bis M7 (mit Team: wechseln) |
| A5 | Ed448- und DSA-Hostschlüssel: Typ wird gezeigt, Fingerabdruck „nicht lesbar“ (kein gemessener Testvektor) | so lassen |
| A6 | `GSSCustom` bleibt als Hinweis vor dem Verbinden (lädt in dieser App nichts mehr) | so lassen (wie entschieden) |
| A7 | Nach „Ohne gespeichertes Passwort verbinden“ verbindet auch jedes weitere „Erneut verbinden“ in diesem Tab ohne Passwort (passt zu 2FA); nach einer Korrektur des Passworts im Editor neu doppelklicken | so lassen |
| A8 | Ein Server kann die Meldung „Configured password was not accepted“ selbst ausgeben; dann erscheint nur das Angebot, ohne Passwort neu zu verbinden – und nur, wenn plink mit Fehler endet | so lassen |
| **E1** | **Kontrast:** Plan 3.1 verlangt dunkle Schrift auf Bernstein. Als `AccentColor` färbt macOS Standardknöpfe und Auswahl selbst – mit **weißer** Schrift auf Bernstein (Kontrast ca. 2:1). Möglich: (a) so lassen bis zum Feinschliff in M7, (b) Akzent dunkler (z. B. `#A05F00`, ca. 5:1 mit weißer Schrift), (c) Akzent nur im Hellmodus dunkler | **entschieden bei der Abnahme: (a)** – so lassen, in M7 messen |

## 6. Reviews

- **ponytail-review + vibe-security (Prüfer-Agent)** über den ganzen Diff: 12 Befunde, alle erledigt – siehe Abschnitt 8.
- **code-review, Achse Spec:** Fingerabdruck kopieren, Agent-Befehl fest, `GSSCustom` als Hinweis, ehrlicher Umgang mit dem Speicher (A2) umgesetzt; „Nachfrage nach Anmeldung“ → A1; Ed448/DSA → A5.
- **code-review, Achse Standards** (Richtlinien + swiftui-pro + Smell-Baseline): „…“ nur bei Knöpfen mit Folgedialog, `private` wo möglich, Inspektor über `endsWithPassword` statt Textvergleich, `isLink` → `entryExists`, ungenutztes `passphraseDescriptors` gelöscht. **Nicht umgesetzt** (Urteilsfrage): ein Typ je Datei in `KeysModel` (Hilfstypen bleiben bei ihrem Modell), Aktionen als kurze Inline-Closures, einige Zeilen über 120 Zeichen.

## 7. Skill-Protokoll

| Skill | Wofür | Übernommen | Nicht übernommen / Grund |
|---|---|---|---|
| `anthropic-skills:ponytail` (ganze Sitzung) | kleinste vollständige Lösung | keine eigene Pageant-Oberfläche, puttygen statt eigener Schlüssel-Code, Inspektor liest `sshhostkeys` statt mitzulesen, ein `ToolWindowController` für beide Fenster | – |
| `anthropic-skills:vibe-security` (ganze Sitzung) | S1–S14, Audit | Pipe statt Datei/Argument, Bindung ans Ziel, kein Passwort bei Proxy/festen Hostschlüsseln, Sperre um `umask`, Verweise in `sshhostkeys` abgelehnt, Grundsatz-Test | Web-Teile (Header, Datenbank, Zahlungen) treffen nicht zu |
| `mattpocock-skills:tdd` | Test zuerst | Bug-Tests vor jedem Fehlerfund (Port, Adresse wie plink, Blockgrenze, `umask`, Installationsbefehl, Passphrase) | Oberflächen-Ansichten ohne Tests (Prüfung per Klick) |
| `mattpocock-skills:code-review` | zwei Achsen, je ein Agent | Abschnitt 6 | kein Issue-Tracker im Repo – Spec = Plan M3 |
| `apple-skills:swift` | Swift 6, Nebenläufigkeit | `nonisolated` Kern-Typen, `@concurrent` für puttygen, typisierte `throws` | – |
| `apple-skills:swiftui` + `anthropic-skills:swiftui-pro` | Ansichten | `Form`-Abschnitte, `fileImporter`, `confirmationDialog`, `ContentUnavailableView`, `@Observable` | „ein Typ je Datei“ nicht durchgezogen (Abschnitt 6) |
| `apple-skills:macos` | AppKit-Gerüst | eigene Fenster per `NSWindowController`, Menüeinträge, Sheets am Fenster | – |
| `apple-skills:design` | Texte | Hinweise zu Schlüsselbund und Hostschlüssel kurz, mit Handlungsanweisung, ohne Fachjargon wo möglich | Feinschliff in M7 |
| `apple-skills:testing` | Swift Testing / XCTest | parametrisierte Kern-Tests, echte Werkzeuge in App-Tests | – |
| `anthropic-skills:computer-use` | Oberflächenprüfung | Hintergrund-Klicks auf die App | Tippen nicht freigegeben |
| `macos-tahoe-apis` | – | – | nicht benutzt: keine neue Tahoe-API nötig, Mindestversion macOS 14 |

## 8. Sicherheits-Audit (vibe-security)

**Umfang:** Diff M3 gegen `m2` (56 Dateien), Schwerpunkt S1, S2, S5, dazu S3, S4, S8, S9, S14.

### Kritisch
Keine.

### Hoch
Keine.

### Mittel
1. **Gespeichertes Passwort trotz fester Hostschlüssel** – `SessionSettings.swift`, `passwordUnavailableReason`. Eine untergeschobene Sitzung (gleiches Ziel + `SSHManualHostKeys=<fremder Schlüssel>`) hätte plink den Schlüssel eines Angreifers ohne Rückfrage annehmen lassen und das Passwort an ihn geschickt (S5). **Behoben:** kein Passwort mit `SSHManualHostKeys`; Test in `PasswordTargetTests`.

### Niedrig
2. **`umask`-Wettlauf** – `TerminalProcess.spawn`: gleichzeitige Starts (puttygen im Hintergrund, plink im Vordergrund) konnten die Maske vertauschen (Kind mit 022 oder App dauerhaft 077). **Behoben:** `NSLock` um `umask`/`posix_spawn`; Test mit 40 gleichzeitigen Starts.
3. **Endtext fälschbar** – `Connection`: Ausgabe „Configured password was not accepted“ vom Server hätte nach normalem Ende „Passwort nicht angenommen“ gezeigt. **Behoben:** nur bei Fehler-Ende und nicht nach eigenem Trennen.
4. **Erkennung über Blockgrenzen ungetestet** – **behoben:** `RejectedPasswordWatch` mit Test für jede Teilungsstelle.
5. **Installationsbefehl konnte `authorized_keys` beschädigen** (letzte Zeile ohne Zeilenende) – **behoben:** `printf '\n%s\n'`; Test führt den Befehl aus (auch mit „'“ im Kommentar).
6. **Passphrase mit Zeilenumbruch** wäre gekürzt worden – **behoben:** abgelehnt in Erzeugen und Passphrase-Sheet; Test.
7. **Überschreiben des Passworts wirkungslos** (`resetBytes` auf `CFData`) – **behoben:** entfernt, `shortcut:`-Vermerk (A2).
8. **Inspektor zeigte Schlüsselbund, obwohl nicht verwendet** – **behoben:** Wert nach dem Start aus `usesStoredPassword`.
9. **Server für Hostschlüssel und Passwort-Ziel anders als plink** (`benutzer@` im Server, `:…`, Leerzeichen, `LogicalHostName`, IPv6-Klammern) – **behoben:** byteweise wie `prepare_session`/`ssh_hostport_setup`; `PlinkAddressTests`. Wirkung vorher: Passwort hätte für einen anderen Benutzer gegolten (gleicher Server), Inspektor fand bekannte Schlüssel nicht.

### Lean / Aufräumen
10. `passphraseDescriptors` gelöscht · 11. doppelte Längenprüfung des Geheimnisses und doppelter Datei-Check entfernt · 12. Messtest ohne Prüfung → prüft jetzt `errSecMissingEntitlement`.

### Bestanden
- **S1:** Passwort nur Schlüsselbund → Pipe (`-pwfile /dev/fd/3`), nie `-pw`, nie Datei, nie Argument/Umgebung, nie Protokoll, nie `UserDefaults` (App- und Grundsatz-Tests). Lokal, nicht synchronisiert.
- **S2:** kein Mitlesen zum Anmelden; die Ausgabe wird nur auf plinks Ablehnungsmeldung geprüft, und die bewirkt höchstens ein Angebot.
- **S3:** puttygen und plink nur mit Argumentliste über `posix_spawn`, Pfade absolut geprüft; kein Shell-Aufruf in der App (der Installationsbefehl wird nur kopiert, nie ausgeführt).
- **S4:** `PublicKeyFile` ohne Zeilenumbruch; Schreiber lehnt `\n`/`\r`/`\0` ab.
- **S5:** Hostschlüssel nimmt nur plink nach Rückfrage an; die App entfernt höchstens Einträge (mit Rückfrage), schreibt nie neue.
- **S8:** Kind erbt nur 0/1/2 und fd 3 (`POSIX_SPAWN_CLOEXEC_DEFAULT`), neue Dateien `0600`.
- **S9:** Protokoll ohne Passwort, Sitzungsname nur gehasht.
- **S14:** Diff ohne IP-Adressen außer `127.0.0.1`/`192.0.2.x`, ohne Benutzernamen und `/Users/`-Pfade (Suche über alle geänderten Dateien); Testsitzung mit Benutzer zur Laufzeit (`id -un`), nur im Cache/PuTTY-Ordner.

**Nicht geprüft:** Verhalten von `SecureField` bei eingefügten Zeilenumbrüchen (abgefangen, egal wie); puttygen-Dateirechte unter umask 022 (kommt nicht mehr vor).

## 9. Abnahme (19.10.2026)

- Leonard: „Programm läuft alles, Abnahme“. E1: Vorschlag (a) übernommen.
- Heimserver von unterwegs nicht prüfbar: Das WLAN, in dem der Mac war, sperrt ausgehend Port 22 (gemessen: auch `github.com:22` nicht erreichbar, Port 443 schon). Dabei fiel auf, dass die eigene Sitzung „Heimserver“ `Protocol=telnet` hatte – Einstellung im Editor auf SSH.
- Idee für M4 (Statuszeile): Solange plink die Netzverbindung aufbaut, bleibt das Terminal leer (bis ca. 75 s bis „Operation timed out“), und der Inspektor zeigt schon „Verbunden“ – dort „Verbinde …“ anzeigen.
- Aufgeräumt: Testsitzung „M3-Test“, `test.ppk` und Testserver entfernt (`ui stop`); der Eintrag für 127.0.0.1:2222 in `sshhostkeys` bleibt (harmlos, über die Liste entfernbar).
