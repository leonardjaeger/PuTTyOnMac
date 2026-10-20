# M4 – Terminal-Komfort: Prüfliste

**Stand:** 20.10.2026 · Version 0.1.1 (Build 2) · Grundlage: Tag `m3` · **abgenommen am 20.10.2026** („passt alles“) · Commit „M4 Terminal-Komfort“, Tag `m4`

Messungen und Machbarkeit: `docs/M4-Machbarkeit.md`. Alle Beispiele nur mit Platzhaltern (S14); Wegwerf-Server,
-Schlüssel und Testsitzungen „M4/Test“, „M4/Tempo“ liegen nur im Cache bzw. im PuTTY-Ordner der App und werden nach
der Abnahme mit `ui stop` entfernt.

## 1. Umsetzung

| Nr. | Punkt | Status | Nachweis |
|---|---|---|---|
| 1 | **Profile**: Name, Schrift (Systemschrift oder installierte Festbreitenschrift), Größe 8–72 pt, Farbschema (Automatisch, Hell, Dunkel, **PuTTY-Standardfarben**), Rückblättern 0–100 000 Zeilen (Standard 2000 wie PuTTY), Cursor (Block, Unterstrich, Strich), Glocke (Ton, Blinken, Aus) | ✅ | Kern `TerminalProfile` (Paletten, PuTTY-Werte aus settings.c, Kontrast ≥ 4,5:1 je Schema, nachsichtiges Laden mit Begrenzung), App `ProfileStore` (UserDefaults, eine Liste für alle Fenster), `TerminalProfileAppearance`; `TerminalProfileTests`, `testProfileStoreKeepsNamesUniqueAndStandard` |
| 2 | Profile bearbeiten in **Einstellungen (⌘,) › Profile**: Liste, „+“ (Kopie des gewählten), „−“ (Standard bleibt), Änderungen sofort auch in offenen Tabs | ✅ | `SettingsWindowController` (Reiter im Symbolleisten-Stil, RL 3.4 Regel 16), `ProfilesSettingsView`, `ProfileEditor` |
| 3 | **Profil je Sitzung** im Editor (Abschnitt „Terminal“), gespeichert als `TunnelTerminalProfile=<UUID>` in der Sitzungsdatei (PuTTY übergeht den Schlüssel); gelöschtes Profil → Standard | ✅ | `SessionFile.profileID`; `testSessionProfileAppliesToTerminalAndFollowsChanges` (Dunkel, 14 pt, 10 000 Zeilen; Änderung wirkt im offenen Tab; Löschen → 13 pt) |
| 4 | **Profil im Inspektor** („Verbindung“): Auswahl gilt für den Tab, bleibt bei ⌘R | ✅ | `ConnectionInspector`, `ConnectionInfo.profileID` |
| 5 | **Suchen** ⌘F (SwiftTerm-Suchleiste), Weitersuchen ⌘G, Rückwärts ⇧⌘G, Auswahl für Suche ⌘E – auch wenn die Seitenleiste den Fokus hat | ✅ | `MainMenu` (Bearbeiten › Suchen), `performTextFinderAction` im Fenster-Controller |
| 6 | **Bildschirm und Verlauf leeren** ⌘K (wie Terminal.app) | ✅ | `clearScreenAndHistory`; `testClearRemovesScrollback` |
| 7 | **Alles kopieren** (Bearbeiten-Menü): Verlauf + Bildschirm als Text, Leerraum am Zeilenende weg | ✅ | `copyEverything`, `testCopyAllTrimsPadding` |
| 8 | **Verbindung duplizieren** ⌘D (neuer Tab, auch mit S4-Rückfrage) | ✅ | `duplicateConnection` |
| 9 | **Titel ändern …** (Fenster-Menü), leer = wieder Adresse/Sitzungsname; Steuerzeichen sichtbar, höchstens 100 Zeichen | ✅ | `changeTitle`, `testCustomTitle` |
| 10 | **F1–F4 optional** (Einstellungen › Allgemein, aus im Standard): F1 Leeren, F2 Alles kopieren, F3 Duplizieren, F4 Titel | ✅ | `AppTerminalView.handleKey` über einen Tasten-Monitor (SwiftTerm erlaubt kein Überschreiben von `keyDown`); `testKeysBeforeTerminal` |
| 11 | **Kopieren beim Markieren** und **Rechtsklick fügt ein** als Optionen (aus im Standard); Rechtsklick geht an das Programm, wenn es die Maus auswertet | ✅ | `AppTerminalView.mouseUp`/`rightMouseDown`, `GeneralSettingsView` |
| 12 | **Einfügen mit Rückfrage (S10)**: jeder Zeilenumbruch (auch einer am Ende) → **Hinweisleiste** über dem Terminal mit Zeilenzahl; Esc bricht ab, ⌘↩ fügt ein (Return allein nicht), andere Tasten piepen; VoiceOver-Ansage; nur ein Einfügen zur Zeit | ✅ | `PasteCheck` (Kern), `PasteBanner`, `requestPaste`/`finishPaste`; `testPasteWithLineBreakWaitsForConfirmation`, `TerminalInputTests` |
| 13 | **Bracketed Paste**: Hat das Programm Modus 2004 an, kommt der Text eingerahmt; ESC im Text wird zu Leerzeichen (kein eingeschleustes `ESC[201~`) | ✅ | SwiftTerm `pasteText`; `testBracketedPaste` |
| 14 | **OSC 52 nur mit Rückfrage (S11)**: Vorschau (10 Zeilen/400 Zeichen, Steuerzeichen sichtbar), „Nicht erlauben“ ist Standard; nach einer Ablehnung keine weiteren Rückfragen dieser Verbindung; über 1 MiB verworfen; Lesen der Zwischenablage bleibt verboten | ✅ | `clipboardCopy`/`clipboardRead`; `testClipboardRequestNeedsConsent`, `testOversizedClipboardRequestIsDropped`, `testClipboardPreview` |
| 15 | **Links (OSC 8, erkannte Adressen) nur mit Rückfrage (S11)**: volle Adresse und „Ziel: <Server>“; nur http, https, mailto – sonst „Dieser Link wird nicht geöffnet.“ | ✅ | `LinkPolicy` (Kern), `requestOpenLink`; `TerminalInputTests.links`, `testLinksAreConfirmedOrRefused` |
| 16 | **Sitzungsprotokoll**, aus im Standard, je Sitzung im Editor; **die App schreibt es selbst** (Abweichung A1): Ordner `~/Library/Logs/TunnelTerminal` (0700), Datei „<Sitzung> <Datum Uhrzeit>.log“ (0600, `O_EXCL`, kein Symlink), Schreiben im Hintergrund, höchstens 1 GiB; Schalter „Protokolle zeigen“ | ✅ | `SessionLogWriter`, `Connection.openLog`, `SessionLogName` (Kern); `testSessionLogRecordsOutput`, `testSessionLogStopsAtLimit`; von mir geprüft: Datei 0600 mit Ausgabe |
| 17 | plinks **SSH-Paketprotokoll** (`LogType` 3/4, enthält Getipptes) aus importierten Sitzungen: Warnung im Editor und beim Import (nicht vorausgewählt); der Schalter ersetzt es | ✅ | `SessionWarning.packetLog`; `SessionWarningTests.logWarnings` |
| 18 | **Statuszeile** unter dem Terminal: Verbinde …/Verbunden/Getrennt, Verbindungsart, Größe (Spalten × Zeilen), UTF-8, Protokoll an/aus | ✅ | `StatusBar`, `ConnectionInfo`; von mir geprüft (Bild) |
| 19 | **„Verbinde …“** im Inspektor und in der Statuszeile, bis plink die erste Ausgabe liefert (Notiz aus M3) | ✅ | `ConnectionInfo.isConnecting` |
| 20 | **Kürzel ohne Doppelbelegung** (⌘K, ⌘D, ⌘F, ⌘G, ⇧⌘G, ⌘E, ⌘, neu) | ✅ | `MainMenuTests.testShortcutsAreUnique`, `testTerminalComfortCommands` |
| 21 | **Tempo bei viel Ausgabe**: `TerminalProcess` liest bis 8 ms je Ereignis statt einen Block (2,6× schneller im Debug-Bau), Hauptschleife höchstens 18–26 ms blockiert | ✅ | `ThroughputTests`, `docs/M4-Machbarkeit.md` 3 |
| 22 | `build/skript.sh` auf `build/m4/`; `watch.sh` hasht künftig `build/m*/*.sh` (wirkt nach Neustart des Bauwächters) | ✅ | `build/m4/machbarkeit.sh`, `ui.sh`, `tempo.sh`, `bench.sh` |

**Tests:** 143 Kern (19 Suiten) + 81 App (10 Klassen), alle grün, ohne Compiler-Warnungen (Läufe `m4k6`, `m4t11`).
Release-Bau fehlerfrei (`m4s13`).

## 2. So prüfst du (du selbst)

Während der Prüfung lief der **Release-Bau** (für ein ehrliches Tempo; `ui neustart` startet wieder den Debug-Bau). In der Seitenleiste
unter „M4“: „Test“ (Wegwerf-Server 127.0.0.1:2222, Schlüssel ohne Passphrase, Protokoll an) und „Tempo“ (gibt
`seq 1 2000000` aus und misst die Zeit). Nach der Anmeldung zeigt plink „Press Return to begin session“ → Return.

- [ ] **Profil:** ⌘, › Profile › „+“ → Name „Dunkel“, Farbschema Dunkel, 14 pt, Rückblättern 10000 → Sitzung „M4/Test“ bearbeiten › Profil „Dunkel“ → verbinden: dunkles Terminal, größere Schrift; während der Verbindung im Profil die Größe ändern → Tab folgt sofort
- [ ] Inspektor › Profil auf „Standard“ → nur dieser Tab wechselt; ⌘R → bleibt
- [ ] `seq 1 500` → ⌘F, „250“ suchen → Treffer; ⌘G weiter; Esc schließt die Suche
- [ ] ⌘K → Bildschirm und Verlauf leer (nach oben scrollen geht nicht mehr); Return bringt die Eingabezeile zurück
- [ ] `ls -l /` → Bearbeiten › Alles kopieren → in Notizen einfügen → Text ohne Leerraum-Schwanz
- [ ] ⌘D → zweiter Tab mit derselben Sitzung; Fenster › Titel ändern … → „Mein Tab“ → Tab-Titel; leer → wieder „M4/Test“
- [ ] **Einfügen:** in TextEdit drei Zeilen (z. B. `echo eins` / `echo zwei` / `echo drei`) kopieren, im Terminal ⌘V → Hinweisleiste „3 Zeilen“; Esc → nichts passiert; nochmal ⌘V, ⌘↩ → die drei Befehle laufen. Eine Zeile ohne Umbruch → sofort eingefügt
- [ ] Mit **VoiceOver** (⌘F5): ⌘V mit mehreren Zeilen → Ansage der Hinweisleiste
- [ ] ⌘, › Allgemein: „Markierten Text sofort kopieren“ an → Text markieren → in Notizen einfügbar; „Rechtsklick fügt ein“ an → Rechtsklick fügt ein (mehrzeilig mit Hinweisleiste); „F1–F4 als Befehle“ an → F2 kopiert alles, F4 öffnet „Titel ändern“ (mit fn)
- [ ] **OSC 52:** `printf '\e]52;c;%s\a' "$(printf 'Hallo vom Server' | base64)"` → Rückfrage mit Vorschau; „Nicht erlauben“ → Zwischenablage unverändert, ein zweites Mal kommt keine Rückfrage mehr; nach ⌘R erneut → „In die Zwischenablage“ → eingefügt
- [ ] **Link:** `printf '\e]8;;https://www.apple.com\e\\Apple\e]8;;\e\\\n'` → ⌘-Klick auf „Apple“ → Rückfrage mit „Ziel: www.apple.com“; `printf '\e]8;;file:///etc/hosts\e\\Datei\e]8;;\e\\\n'` → „Dieser Link wird nicht geöffnet.“
- [ ] **Protokoll:** „M4/Test“ hat das Protokoll an (Statuszeile „Protokoll an“). Im Terminal `read -s x` tippen, Return, ein Wort tippen, Return, dann `echo sichtbar` → trennen → Editor › „Protokolle zeigen“ → neueste Datei: enthält „sichtbar“, **nicht** das verdeckt getippte Wort (Prüfpunkt „Passwort nicht im Protokoll“)
- [ ] **Tempo:** Doppelklick „M4/Tempo“, Return → am Ende stehen `real … user … sys …` vom Server; Fenster bleibt währenddessen bedienbar (Zeit notieren, Messwert für den Plan)
- [ ] Hell und dunkel: Statuszeile, Hinweisleiste und Einstellungen gut lesbar
- [ ] In Xcode ⌘U: alle Tests grün

## 3. Von mir geprüft (Oberfläche, per Klick)

TunnelTerminal ist für mich nur zum **Anklicken** freigegeben (Terminal-Apps: kein Tippen, keine Tasten, keine Menüs).
Geprüft habe ich deshalb nur, was Knöpfe erreichen:
- Hauptfenster mit **Statuszeile**: „Verbunden · SSH · 93 × 37 · UTF-8 · Protokoll aus“, nach Trennen „Getrennt“, mit Protokoll „Protokoll an“.
- **Inspektor**: Abschnitt „Verbindung“ mit Profil-Auswahl „Standard“, Hostschlüssel-Abschnitt unverändert.
- **Editor**: Abschnitt „Terminal“ mit Terminaltyp, Profil, Schalter „Sitzungsprotokoll“, Fußtext und „Protokolle zeigen“; Schalter eingeschaltet → nach dem Verbinden Datei `M4-Test <Datum>.log` mit Rechten 0600 im Ordner 0700, Inhalt = Ausgabe.
- Hostschlüssel-Warnung von plink, als der Wegwerf-Server einen neuen Schlüssel hatte (S5 greift); angenommen habe ich ihn per Skript für diesen Testserver (`ui hostkey`).
- **Nicht von mir geprüft** (braucht Tastatur/Menü): Einstellungsfenster, Hinweisleiste beim Einfügen, Suchleiste, ⌘K, Alles kopieren, Titel ändern, F-Tasten, OSC-52-/Link-Rückfragen in echt. Diese Wege decken App-Tests ab; die Sichtprüfung liegt bei dir (Abschnitt 2).

## 4. Abweichungen und Entscheidungen

| Nr. | Thema | Stand |
|---|---|---|
| A1 | **Sitzungsprotokoll nicht über `-sessionlog`**: plink schreibt damit (und mit `LogType` 1/2) gar keine Datei, das Paketprotokoll enthielte Getipptes. **Entschieden am 19.10.2026 (du): „App schreibt selbst“.** Schalter über `LogType` (2 = an, 0 = aus); `LogFileName` gilt nicht, die App wählt Ordner und Namen. Enthält alles Sichtbare, auch getippte Befehle (Echo), nicht verdeckte Eingaben | umgesetzt |
| A2 | Schnellverbindungen schreiben kein Protokoll (keine Sitzung, kein Schalter) | bei der Abnahme so belassen |
| A3 | Importiertes `LogType=1` („druckbare Ausgabe“) wird wie 2 behandelt: die App speichert die rohe Ausgabe mit Farbsequenzen | bei der Abnahme so belassen |
| A4 | Links nur http, https, mailto (strenger als S11 verlangt; `ssh://` kommt in M7 mit eigener Bestätigung) | bei der Abnahme so belassen |
| A5 | Zusätzliche Suchkürzel ⌘G, ⇧⌘G, ⌘E (Mac-Standard) | bei der Abnahme so belassen |
| A6 | „Alles kopieren“ nimmt im Vollbild-Programm (vim, less) nur dessen Bildschirm, sonst Verlauf + Bildschirm | bei der Abnahme so belassen |
| A7 | Statuszeile zeigt grün „Verbunden“, sobald plink etwas ausgibt – auch schon bei Hostschlüssel-Frage oder Anmeldung (die App sieht nicht, wann die Anmeldung fertig ist, ohne mitzulesen, S2) | bei der Abnahme so belassen |
| A8 | Text, den ein macOS-**Dienst** ins Terminal einsetzt, geht ohne Hinweisleiste an SwiftTerm (seltener Weg, kein Server-Einfluss) | Kann in M7 |
| A9 | **Tempo:** Im Release-Bau begrenzt plink (≈ 3 MB/s), nicht die App; Debug-Bau ≈ 1 MB/s wegen unoptimiertem SwiftTerm | Hinweis |
| A10 | **Für M5:** plink schaltet bei Raw (vermutlich Telnet) das Terminal nie roh – Eingaben werden zeilenweise gepuffert (`docs/M4-Machbarkeit.md` 2) | in M5 prüfen |
| A11 | Tippen in TunnelTerminal ist für Claude nicht freigegeben (Terminal-Kategorie, nur Klicks); Menübefehle erreichte ich auch mit Vollbild-Steuerung nicht | Hinweis |
| A12 | Bauwächter neu starten, damit `watch.sh` auch `build/m*/*.sh` ins Log hasht (`skript.sh` gibt den Inhalt ohnehin aus) | bei Gelegenheit |

## 5. Skill-Protokoll

| Skill | Wofür | Umgesetzt | Bewusst nicht |
|---|---|---|---|
| `anthropic-skills:ponytail` (genannt) | ganze Sitzung aktiv | Plattform zuerst: SwiftTerm-Suchleiste, Bracketed Paste und Steuerzeichen-Entschärfung von SwiftTerm, `CSI 3 J` für ⌘K, `getBufferAsData` für „Alles kopieren“; keine eigene Profil-Datei (UserDefaults); Statuszeile/Hinweisleiste in bestehende Slots von `TerminalArea` | Option „Rückfrage beim Einfügen abschalten“, Protokoll-Ordner wählbar, Protokoll-Kopfzeile, Profile exportieren (nicht verlangt) |
| `anthropic-skills:vibe-security` (genannt) | S1–S14 vor dem Code, Audit am Ende | Abschnitt 6; Vorab: Link-Schemata begrenzen, OSC-52-Lesen aus, Protokolldatei 0600/`O_EXCL`/`O_NOFOLLOW`, Profil-Daten begrenzt | Web-Abschnitte (Supabase, Stripe, Next.js, LLM …) nicht zutreffend |
| `anthropic-skills:ponytail-review` | Prüfer-Agent über den M4-Diff | Befunde 3–7, 9, 10 behoben (Abschnitt 7) | Befund 1 widerlegt (Test belegt), 2 geprüft (Kitty-Zwischenablage aus, kein Drag & Drop/Mittelklick-Einfügen in SwiftTerm), 6/8 als A7/A3 |
| `apple-skills:macos` | AppKit-Einbettung, Einstellungen, Barrierefreiheit | NSHostingView mit `sizingOptions`, Einstellungen als `NSTabViewController` | `macos-tahoe-apis/` (RL 7.4 Regel 4) |
| `apple-skills:swift` | Swift 6 / Nebenläufigkeit | Protokoll-Schreiben auf serieller Queue nur mit `Sendable`-Werten (`FileHandle`, `Data`); MainActor-Grenzen der Monitore | — |
| `apple-skills:testing` + `mattpocock-skills:tdd` | Test zuerst für Kern-Bausteine | Kern-Tests rot → grün (`m4k1` → `m4k5`, `m4k6`); Grundsatz-Test S1 griff einmal (Kommentar mit „Geheimnisse“) | Seams nicht vorab mit dir abgestimmt (Prompt: „keine offenen Entscheidungen“) – Seams: `TerminalProfile`, `PasteCheck`, `LinkPolicy`, `SessionLogName`, `SessionFile`-Schlüssel |
| `apple-skills:performance` | Tempo bei viel Ausgabe | Messung in drei Ebenen (plink, Parser, App-Weg), Engpass „ein Block je Leseereignis“ behoben, Hang-Grenze 250 ms im Test | Instruments-Lauf (kein Zugriff auf die Oberfläche von Instruments) |
| `apple-skills:swiftui` + `anthropic-skills:swiftui-pro` | Einstellungen, Editor, Statuszeile, Hinweisleiste | `foregroundStyle`, Buttons mit Text (auch „+“/„−“ mit `labelStyle(.iconOnly)`), `onChange` mit 2/0 Parametern, `@AppStorage` mit Schlüsseln aus `AppSettings` | „ein Typ je Datei“ bei `ProfileTitles` (drei kleine Erweiterungen), feste Breiten im Einstellungsfenster |
| `apple-skills:design` | Texte, Symbole, Kontrast | Rückfrage-Texte nach PACE (was passiert, was tun), SF Symbols, Kontrast der festen Schemata ≥ 4,5:1 im Test | eigene Farben in der Oberfläche (nur Systemfarben) |
| `anthropic-skills:computer-use` | eigene Oberflächenprüfung | Klickprüfung (Abschnitt 3) | Tastatur/Menüs nicht freigegeben |
| `mattpocock-skills:code-review` | Spec und Standards (zwei Agenten) | Abschnitt 7 | Beide Agenten verloren mittendrin die Verbindung zum Mac (Mac schlief): geprüft ~55 % (Spec) bzw. ~40 % (Standards) |

## 6. Sicherheits-Audit (vibe-security)

Nicht zutreffend: Datenbank-Zugriffsregeln, Auth/JWT, Rate-Limits, Zahlungen, Mobile, KI-Schlüssel, Web-Deployment, SQL.
Geprüft: Geheimnisse, Eingaben an Vertrauensgrenzen (Server-Ausgabe → Terminal/Zwischenablage/Links, fremde
Sitzungsdateien, Einstellungen), Dateien auf dem Mac, Missbrauch durch den Server.

**Kritisch:** keine. **Hoch:** keine offen.

**Mittel (behoben)**
- `ConnectionWindowController.clipboardCopy` – **OSC-52-Flut sperrt den Tab**: Ein Server konnte nach jeder Ablehnung sofort die nächste Rückfrage auslösen.
  Vorher: `guard response == .alertSecondButtonReturn else { return }` · Nachher: Ablehnung setzt `clipboardRefused`, weitere Anfragen bis zum nächsten Verbinden ohne Rückfrage verworfen (Test).
- `SessionLogWriter.write` – **Protokoll ohne Grenze**: Endlose Ausgabe hätte die Platte gefüllt.
  Vorher: `queue.async { try? handle.write(contentsOf: data) }` · Nachher: ab 1 GiB nichts mehr, Datei zu, Hinweis im Terminal (Test).
- `SessionEditor` – **falsche Datenschutz-Aussage**: „nie Getipptes“ → jetzt „auch getippte Befehle, nicht aber verdeckte Eingaben wie Passwörter“.

**Niedrig (behoben)**
- Link-Rückfrage: Täuschung über einen Benutzerteil (`https://bank.example@boese.example`) – jetzt „Ziel: boese.example“ eigens (Test).
- Hinweisleiste: Esc/⌘↩ wirkten nicht, wenn der Fokus nicht im Terminal lag (z. B. Rechtsklick-Einfügen aus einem Feld) – Fokus wird gesetzt.

**Niedrig (offen, siehe A7/A8)**: Statuszeile „Verbunden“ während Abfragen; Einfügen über macOS-Dienste ohne Hinweisleiste.

**Ohne Befund**
- S1/S3/S5 unverändert: plink weiter nur `-load` (+ `-pwfile /dev/fd/3`), Passwort nur über Pipe, Hostschlüssel nie automatisch. Die Sitzungsdatei wird beim Start jetzt einmal statt zweimal gelesen.
- S4: neuer Sitzungsschlüssel `TunnelTerminalProfile` geht über `setValue` (CR/LF/NUL abgelehnt), gelesen nur als UUID.
- S9: kein neuer Protokollaufruf mit Werten; Grundsatz-Tests grün.
- S10: Hinweisleiste vor jedem Zeilenumbruch; SwiftTerm ersetzt NUL, ESC, DEL, ^C, ^Z … durch Leerzeichen, auch in Bracketed Paste (Test mit `ESC[201~`).
- S11: OSC 52 nur mit Zustimmung, Lesen verboten; OSC 5522 (Kitty-Zwischenablage) bleibt aus (SwiftTerm-Standard: keine Fähigkeiten); Links nur http/https/mailto mit Rückfrage; Drag & Drop und Mittelklick-Einfügen gibt es in SwiftTerm nicht.
- Dateien: Protokoll 0600, Ordner 0700, `O_EXCL|O_NOFOLLOW|O_CLOEXEC`, Name ohne „/“, „:“, führenden Punkt, ≤ 255 Bytes.
- Einstellungen: Profile aus UserDefaults werden geprüft und begrenzt (Name, Größe auch bei NaN, Rückblättern, doppelte Kennungen), Standardprofil immer da.
- S12/S14: keine Adressen, Namen oder `/Users/`-Pfade in Code, Tests oder Doku; Bundle-Kennung nur aus `AppIdentity`.

## 7. Reviews

**Prüfer-Agent (ponytail-review + vibe-security)**, Produktionscode vollständig, Tests nicht (Mac schlief ein):
1 Einfügen ohne Bracketed Paste kommt nicht an – *widerlegt* (SwiftTerm schickt nach unserer Rückfrage mit `allowUnsafe`; Test belegt „a⏎b“ → `a\rb`) · 2 weitere Einfügewege – *geprüft, ohne Befund* (A8 bleibt) · 3 OSC-52-Flut – *behoben* · 4 Protokoll-Text – *behoben* · 5 Protokoll-Grenze – *behoben* · 6 Statuszeile – *A7* · 7 Fokus der Hinweisleiste – *behoben* · 8 `LogType` 1 roh – *A3* · 9 `watch.sh` verlor das Ausführrecht – *behoben* · 10 Link-Ziel – *behoben* · Lean: Queue-Kennung aus `AppIdentity` – *übernommen*.

**code-review Spec** (bis Diff-Zeile 1520): Profil-Wahl im Inspektor ging bei ⌘R verloren – *behoben*; ⌘K-Verlauf ohne Test – *Test ergänzt*; Scope: Link-Schemata, Suchkürzel, „Alles kopieren“ im Vollbild-Programm – *A4–A6*.

**code-review Standards** (bis Diff-Zeile 1130): `watch.sh`-Rechte – *behoben*; F-Tasten-`default` – *jetzt `case 4`*; Titel-Formel doppelt – *eine Stelle* (`defaultTitle`); Profile beim Speichern stumm gelöscht, falls Kodieren scheitert – *behoben*. Ermessen, so belassen: Fenster-Controller wächst um ~300 Zeilen (Einfügen, OSC, Titel – Aufteilen bei M5/M6 prüfen), `Bool` für Entscheidungen, Testzugänge `internal` (`trimmed`, `preview`, `requestPaste`, `finishPaste`, `setCustomTitle`), Schlüssel „Profile“ im `ProfileStore` statt in `AppSettings`.
