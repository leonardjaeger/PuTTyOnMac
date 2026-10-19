# M2 – Sitzungsverwaltung + Gerüst B „Werkbank“: Prüfliste

**Stand:** 19.10.2026 · Version 0.1.1 (Build 2) · Grundlage: Tag `u1` · **abgenommen am 19.10.2026** („passt“, offene Punkte 1–7 bestätigt) · Commit „M2 Sitzungsverwaltung“, Tag `m2`

M2 wurde zuerst mit eigenem Fenster „Sitzungen“ gebaut und dann, wie entschieden (Plan Version 9, Abschnitt 3.1, Entscheidung 10), in das Gerüst B umgebaut: **ein Hauptfenster** mit Seitenleiste, Terminal in Tabs und Inspektor. Das Aussehen im Detail folgt in M7; jede Funktion bekommt ab jetzt ihren Platz im Gerüst. Sicherung des Stands davor: `build/m2/sicherung-vor-geruest-B.tgz` (nicht im Repo).

## 1. Umsetzung

| Nr. | Punkt | Status | Nachweis |
|---|---|---|---|
| 1 | Seitenleiste im Hauptfenster (früher eigenes Fenster „Sitzungen“): oben Schnellverbindung und Suche (Name und Server), dann „Standardeinstellungen“ und Gruppen-Abschnitte („Ohne Gruppe“, dann Gruppen), Server als zweite Zeile, Doppelklick verbindet (auch mehrere) | ✅ | `SessionSidebar`, `SessionRow`, `SessionLibrary.groups`; Sortierung wie im Finder (`localizedStandardCompare`); Tests `testListsSavedSessions…`, `testSearchesNameAndHost`, `testGroupsSortLikeFinder` |
| 2 | Gruppen stehen im Sitzungsnamen („Gruppe/Titel“) | ✅ | `docs/adr/0001-gruppen-im-sitzungsnamen.md` (Unix-PuTTY schreibt nur bekannte Schlüssel zurück, ein eigener `Folder`-Schlüssel ginge verloren) |
| 3 | Editor als Sheet am Hauptfenster (Stift unten in der Seitenleiste, Kontextmenü „Bearbeiten …“, Verbindung › Sitzung bearbeiten …, neue Sitzung öffnet ihn direkt; „Verbinden“ und „Fertig“ unten) im PuTTY-Aufbau, nur häufige Felder: Sitzung (Name, Gruppe, Server, Protokoll, Port, Benutzer), Terminal (Typ), Verbindung (Keepalive, TCP-Keepalives), Proxy (Anzeige + „Proxy ausschalten“, nur wenn einer eingestellt ist), SSH (Komprimierung, Agent-Weiterleitung, Befehl auf dem Server); Hinweise oben; „n weitere Werte bleiben unverändert“ | ✅ | Speichert jede gültige Änderung sofort; Fehler stehen mit Symbol und Text unter dem Feld; der Name wird erst übernommen, wenn Name **und** Gruppe verlassen werden oder mit Return. Port folgt dem Protokoll (22 ↔ 23), Keepalive wie PuTTY in Minuten + Sekunden |
| 4 | Rundlauf: unbekannte Schlüssel byte-gleich | ✅ | `SessionSettingsTests.editsInPlace` mit typischer PuTTY-0.85-Datei (unbekannter Schlüssel, Zeile ohne „=“, CR am Zeilenende, ungültiges UTF-8): nur die bearbeiteten Zeilen ändern sich |
| 5 | Duplizieren, Umbenennen, Löschen, Neue Sitzung, Import – alles mit ⌘Z/⇧⌘Z | ✅ | Bearbeiten › Widerrufen/Wiederholen (Titel z. B. „Löschen widerrufen“), Duplizieren (ohne Kürzel, ⌘D bleibt für M4), Löschen ⌘⌫ (im Textfeld bleibt ⌘⌫ beim Feld). Nach ⌘Z baut sich der Editor neu auf und die Auswahl fällt auf vorhandene Sitzungen zurück. Umbenennen nur in Groß/klein klappt. Tests in `SessionLibraryTests` |
| 6 | Import aus PuTTY-Ordner (`~/.config/putty`, `~/.putty` oder deren `sessions`) | ✅ | Ablage › Importieren › PuTTY-Ordner …; liest nur, ändert keine Rechte; Verweise, Ordner, Dateien > 1 MiB, NUL-Bytes und kaputte Namen werden gemeldet statt gelesen (`PuTTYFolderTests`) |
| 7 | Import aus Windows-`.reg` | ✅ | Ablage › Importieren › Registrierungsdatei (.reg) …; UTF-16LE mit BOM, UTF-8, REGEDIT4/Windows-1252; nur Abschnitte direkt unter `HKCU\Software\SimonTatham\PuTTY\Sessions\`; Texte und `dword` (auch negativ), hex-Werte/Standardwert/kaputte Zeilen mit Hinweis übersprungen; höchstens 16 MiB. Leser in den Robustheitstests (3000 zufällige Veränderungen) |
| 8 | Importvorschau mit Warnliste (S4) | ✅ | Häkchen je Sitzung; nicht vorausgewählt: Standardeinstellungen (ersetzen die eigenen), Gefährliches, Sitzungsprotokoll, feste Hostschlüssel. Nicht importierbar: ungültige/reservierte Namen, zu lange Namen, Sitzungen > 1 MiB, ungültiger Server/Benutzer (S3). Namenskonflikte bekommen „ 2“, „ 3“ (ohne Groß/klein). `ProxyPassword` wird nicht übernommen (S1) |
| 9 | Rückfrage vor jedem Verbinden bei Gefährlichem | ✅ | Lokaler Proxy-Befehl und eigene GSSAPI-Bibliothek, auch über eine SSH-Proxy-Sitzung; alle Gefahren im Hinweis; Befehl mit eingesetzten Platzhaltern/Escapes und sichtbaren Steuerzeichen. Ist eine beteiligte Sitzung nicht lesbar: kein Verbinden |
| 10 | Export als `.reg` und als PuTTY-Ordner | ✅ | Ablage › Exportieren; Auswahl oder (ohne Auswahl) alle. `.reg` wie regedit (UTF-16LE, BOM, CRLF), `dword` nur für die 174 Zahlen-Schlüssel aus dem PuTTY-0.85-Quelltext (`build/m2/putty-zahlen-schluessel.py`), Datei mit 0600. Ordner: `<Ziel>/sessions/…`, 0700/0600; ein fremder, nicht leerer Ordner wird abgelehnt |
| 11 | Testdateien nur mit Platzhaltern (S14) | ✅ | `server.example`, `192.0.2.x`, `test`, `127.0.0.1`; Importquellen für die Prüfung erzeugt `build/m2/testquellen.sh` |
| 12 | Gespeicherte Sitzungen verbinden | ✅ | plink direkt mit `-load <Name>` (keine Zwischendatei), Tab-Titel = Sitzungsname; Rückfrage, Inspektor und plink lesen denselben PuTTY-Ordner wie die Seitenleiste; Sitzungsnamen geprüft (kein „-“, kein „.“ am Anfang, keine Steuerzeichen, ≤ 200 Byte, Dateiname ≤ 255 Byte) |
| 13 | **Hauptfenster** (Gerüst B): `NSSplitViewController` mit Seitenleiste (210–360 pt), Inhalt (≥ 360 pt) und Inspektor (220–340 pt); Werkzeugleiste mit Seitenleiste, „Trennen“ (nur verbunden aktiv) und Inspektor; Fenster 1180 × 680, mindestens 820 × 360 | ✅ | `ConnectionWindowController`, `TerminalArea` (Inhalt unter dem sicheren Bereich, RL 3.4), `testWindowHasSidebarContentAndInspector` |
| 14 | **Schnellverbindung** oben in der Seitenleiste (`benutzer@server:port`, SSH/Telnet/Raw), ⇧⌘K setzt den Fokus, Return verbindet; Optionen wie `-o…` werden abgelehnt (S3) | ✅ | `QuickConnectField`, `QuickConnect`; Fehler unter dem Feld; Test `testQuickConnectRejectsOptions` |
| 15 | **Tabs**: Fenster-Tabs von macOS (⌘T neuer Tab mit leerer Startansicht, ⌘N neues Fenster); ist der Tab schon belegt, öffnet eine Verbindung in einem neuen Tab; Sichtbarkeit von Seitenleiste und Inspektor wird übernommen | ✅ | `AppDelegate.newWindowForTab`, `ConnectionWindowController.request` |
| 16 | **Startansicht** „Nicht verbunden“ im leeren Tab, ohne Sitzungen mit „Neue Sitzung“ und „Importieren“ | ✅ | `StartView` |
| 17 | **Inspektor** „Verbindung“: Status, Server (IPv6 in Klammern), Benutzer („Beim Verbinden fragen“), Verbindungsart, Anmeldung (Schlüsseldatei nur mit Dateinamen, Agent wie PuTTY `TryAgent`); ohne Verbindung „Keine Verbindung“ | ✅ | `ConnectionSummary` (Kern, 6 Tests inkl. versteckter Zeichen), `ConnectionInspector`; Darstellung › Inspektor ein-/ausblenden ⌥⌘I |
| 18 | **Status** in der Liste: gefüllter Punkt = verbunden (auch in mehreren Tabs gezählt), leer = getrennt; VoiceOver liest „Verbunden“/„Nicht verbunden“ | ✅ | `ConnectedSessions`, `SessionRow`; Test `testConnectedSessionsCountTabs` |
| 19 | **Ende einer Verbindung**: Leiste über dem Terminal („Verbindung beendet …“, „Erneut verbinden“ ⌘R), Trennen ⌘. bzw. Werkzeugleiste | ✅ | `EndedBanner`, `ConnectionInfo` |
| 20 | **Menüs** angepasst: Darstellung › Seitenleiste ein-/ausblenden ⌃⌘S, Inspektor ⌥⌘I; Verbindung › Schnellverbindung ⇧⌘K, Verbinden, Sitzung bearbeiten …, Erneut verbinden ⌘R, Trennen ⌘.; „Fenster › Sitzungen ⌘0“ entfällt | ✅ | `MainMenu`, `MainMenuTests`; während eines Sheets sind alle Befehle außer „Trennen“ gesperrt |
| 21 | Fachbegriffe ergänzt | ✅ | `docs/CONTEXT.md`: Hauptfenster, Seitenleiste, Inspektor, Startansicht, Status |

## 2. So prüfst du

Die App startet mit dem Hauptfenster, der Fokus steht in der Schnellverbindung. In ihrem PuTTY-Ordner liegen fünf Testsitzungen aus meiner Prüfung (nur Platzhalter): „Unix/Testserver“, „Windows/Mit Befehl“, „Windows/Mit Befehl 2“, „Windows/Proxy mit Befehl“ (Proxy inzwischen ausgeschaltet), „Windows/Testserver“. Lösche sie nach der Prüfung (Auswahl, ⌘⌫) – oder sag mir, ich lösche sie. Die Sitzung „Gefahr Test“ für die Rückfrage habe ich schon wieder entfernt.

**Neu mit Gerüst B**

- [ ] **Schnellverbindung tippen**: ⇧⌘K, `test@127.0.0.1:2222` bzw. ein eigener Server, Return → Terminal im Tab, Punkt/Inspektor zeigen „Verbunden“
- [ ] **⌘T** öffnet einen leeren Tab; Doppelklick auf eine Sitzung verbindet dort; in einem belegten Tab öffnet sie einen neuen Tab
- [ ] **Seitenleiste ⌃⌘S und Inspektor ⌥⌘I** ein-/ausblenden, Fenster schmal ziehen – nichts wird abgeschnitten
- [ ] **Editor-Sheet**: Stift unten links, Name ändern, „Verbinden“ im Sheet verbindet mit dem neuen Namen
- [ ] **⌘⌫ im Editor-Sheet** löscht Text, nicht die Sitzung; ⌘⌫ in der Liste löscht (mit ⌘Z zurück)
- [ ] **Trennen** (Werkzeugleiste oder ⌘.) → Leiste „Verbindung beendet“, Punkt leer; **⌘R** verbindet neu
- [ ] **Rückfrage auf jedem Weg**: `build/m2/Testquellen/windows-export.reg` importieren und „Proxy mit Befehl“ anhaken (heißt dann „… 2“) – Doppelklick, Verbindung › Verbinden, ⌘R und „Erneut verbinden“ fragen jedes Mal
- [ ] **Helles Erscheinungsbild** (Systemeinstellungen) – habe ich nicht geprüft

**Aus M2**

- [ ] **Drei Sitzungen anlegen** (+ bzw. ⇧⌘N), eine mit anderem Port, eine mit Benutzername; Name tippen, Tab, Gruppe tippen → erst danach wird umbenannt
- [ ] **In eine Gruppe einsortieren** (Feld „Gruppe“), **suchen** (Name und Server), **Doppelklick** verbindet
- [ ] **Umbenennen und ⌘Z**: Editor zeigt danach keine verwaiste Sitzung
- [ ] **Homebrew-PuTTY-Sitzung importieren und verbinden** (Ablage › Importieren › PuTTY-Ordner …; bei dir liegt in `~/.putty` nur `randomseed`, also eine echte Sitzung von einem anderen Rechner nehmen oder mit Homebrew-PuTTY anlegen)
- [ ] **Windows-`.reg` importieren**: z. B. `build/m2/Testquellen/windows-export.reg` (erzeugt mit `bash build/m2/testquellen.sh`) – „Proxy mit Befehl“ zeigt eine orange Warnung und ist nicht vorausgewählt; Verbinden fragt jedes Mal nach
- [ ] **Exportieren und wieder importieren** (beide Formate) ergibt dieselben Einstellungen – die Sichern-Dialoge durfte ich nicht bestätigen (siehe 4.)
- [ ] **Verbinden mit Anmeldung** zu einem echten Server (Hostschlüssel bestätigen, Passwort) – in Terminal-Fenstern darf ich nicht tippen
- [ ] **Xcode:** ⌘U alle Tests grün, keine Warnungen

## 3. Messwerte

| Messung | Ergebnis |
|---|---|
| Tests | **104 Kern-Tests** (12 Suiten, Swift Testing) + **46 App-Tests** (XCTest, 5 Klassen), alle grün (Auftrag `m2Bt9`) |
| Debug-Bau | ok, ohne Compiler-Warnungen (`m2Bt9`; nur der übliche Xcode-Hinweis „Metadata extraction skipped“ von appintentsmetadataprocessor) |
| Personendaten im Repo (S14) | Suche nach privaten IP-Bereichen, Heimserver, Benutzerpfaden in allen 154 Dateien: nur Erwähnungen in Doku/`.gitignore`, keine Daten; der Name nur in der erlaubten Bundle-ID |
| Robustheit `.reg`-Leser | 3000 zufällig veränderte Exporte ohne Absturz, kein NUL in Sitzungen |
| Rechte | PuTTY-Ordner 0700/`sessions` 0700, alle Sitzungen 0600 (Auftrag `m2u13`); `.reg`-Export 0600 (Test) |

## 4. Eigene Oberflächenprüfung (Computer-Steuerung, Debug-Build)

**Gerüst B (19.10.):** Hauptfenster mit Fokus in der Schnellverbindung, Seitenleiste mit Gruppen und Statuspunkten, Startansicht und „Keine Verbindung“ im Inspektor; Doppelklick → Terminal im Tab, Inspektor füllt sich (Server, Benutzer, Verbindungsart, Anmeldung), Punkt gefüllt; neuer Tab; Trennen → Leiste „Verbindung beendet“, Punkt leer; Seitenleiste und Inspektor aus- und einblenden; Stift → Editor-Sheet, „Verbinden“ aus dem Sheet; Testsitzung mit lokalem Proxy-Befehl → **Rückfrage als Sheet**, Seitenleiste und Werkzeugleiste dahinter gesperrt; Abbrechen → „Nicht verbunden.“; „Erneut verbinden“ → fragt **wieder**; Verbinden → plink startete den Befehl und endete („Remote side unexpectedly closed“, erwartet bei `echo`).

**Gefunden und behoben (Gerüst B):** Schnellverbindungs-Platzhalter abgeschnitten → Feld über die volle Breite, Protokollwahl darunter. Das Menü „Verbindung“ ist für mich nicht bedienbar → sichtbarer Stift-Knopf unten in der Seitenleiste (hilft auch beim Finden). Rückfrage, Inspektor und plink lasen den PuTTY-Ordner der App fest statt den der Seitenleiste (in der App derselbe Ordner, im Test nicht – der neue Test fand es) → beide nehmen jetzt den Ordner der Bibliothek.

**M2 (18.10.):** Gesehen und bedient: Startfenster „Sitzungen“ (leer mit „Neue Sitzung“/„Importieren“), `.reg`-Import mit Vorschau (Standardeinstellungen „ersetzt die eigenen“, „Proxy mit Befehl“ orange und nicht vorausgewählt, „Mit Befehl“ mit Hinweisen und „„Binaer“ übersprungen“, „-Option“ rot „Wird nicht importiert“), Ordner-Import, Gruppen „Unix“/„Windows“, Editor mit Hinweisen und Proxy-Abschnitt, Doppelklick → Fenster „Unix/Testserver“, plink fragt nach dem **unbekannten Hostschlüssel** (nicht übernommen), Schließen fragt „Verbindung zu „Unix/Testserver“ trennen?“; „Proxy mit Befehl“ → Rückfrage, Abbrechen → „Nicht verbunden.“, „Erneut verbinden“ fragt wieder, Verbinden → Befehl lief, plink endete; „Proxy ausschalten“ → Warnung weg (`ProxyMethod=0`); Duplizieren → „Mit Befehl 2“, Löschen, Widerrufen; Neue Sitzung, TCP-Keepalives, Protokoll Telnet → Port 23 (Datei geprüft).

**Gefunden und behoben:** Ein gemeinsamer Dialog für „Datei oder Ordner“ öffnete einen markierten Ordner, statt ihn zu wählen → getrennte Befehle für `.reg` und Ordner. Die Rückfrage wiederholte ihren Titel → neu formuliert.

**Nicht selbst geprüft:** Tippen (Schnellverbindung, Namen, Suche, Felder) – die App ist als Terminal-App nur zum Klicken freigegeben; Sichern-Dialoge des Exports (darf ich nicht bestätigen); Anmeldung nach dem Hostschlüssel; helles Erscheinungsbild.

## 5. Sicherheits-Audit (vibe-security, eigene Prüfung + Prüfer-Agenten)

Die Web-Abschnitte (Datenbank, Zahlung, Auth) betreffen die App nicht; geprüft wurden Vertrauensgrenzen (`.reg`, fremde Ordner), Prozessstart und Dateien.

**Kritisch – behoben**
- **Warnung umgehbar über Zahlen** (Code-Review): Die App las Zahlen nicht exakt wie plink (`(int)strtol`). `ProxyMethod=00000000005`, `<VT>5` oder `4294967301` waren für die App 0 bzw. ungültig, für plink 5 = lokaler Befehl → Ausführung ohne Warnung. Jetzt exakt nachgebildet (C-Leerraum, alle Ziffern, Sättigung, 32 Bit) mit Tests.
- **Fremde Bibliothek in plink** (eigene Prüfung): `GSSCustom` wird von plink beim SSH-Verbinden per `dlopen` geladen (unix/gss.c, unser Bau hat GSSAPI „DYNAMIC“). Jetzt gefährlich: nicht vorausgewählt, Rückfrage.

**Mittel – behoben**
- Rückfrage fiel weg, wenn die Sitzung nicht lesbar war (z. B. importierte Sitzung > 1 MiB) bzw. ohne Fenster → jetzt kein Verbinden; zu große Sitzungen werden nicht importiert.
- Rückfrage prüfte nur die oberste Sitzung: plink lädt bei SSH-Proxy (`ProxyMethod` 6–8) die Sitzung aus `ProxyHost`, sonst die Standardeinstellungen (proxy/sshproxy.c, im Quelltext bestätigt) → Kette wird aufgelöst (gegen Schleifen geschützt).
- Befehl hinter Platzhaltern/Escapes versteckt (`%host`, `%user`, `\x3b`) → angezeigt wird der Befehl, wie plink ihn ausführt; Passwort als „••••“.
- Server/Benutzer beim Import ungeprüft (S3) → wie im Editor geprüft. `ProxyPassword` im Klartext (S1) → nicht übernommen; `.reg`-Export jetzt 0600.
- Absturz beim Start, wenn `A` und `%41` im Ordner liegen → nur Dateinamen, die die App selbst so schreibt.
- Versteckte Namen („.“, „..“, „.schreiben-…“ wäre beim Start gelöscht worden) → abgelehnt; Dateiname > 255 Byte → abgelehnt.

**Niedrig – behoben:** Steuer-/Richtungszeichen (U+202E) in Befehlen, Namen und Hinweisen werden sichtbar gemacht; quadratischer Aufwand bei Fortsetzungszeilen im `.reg`-Leser; Löschen einer nicht lesbaren Sitzung (wäre nicht widerrufbar) wird abgelehnt; „Name 2“ wird geprüft; feste Hostschlüssel (`SSHManualHostKeys`) und Sitzungsprotokoll nicht vorausgewählt.

**Gerüst B – Prüfer-Agent (Code-Review mit vibe-security), alle Muss-/Soll-Punkte behoben**
- ⌘⌫ wirkte auch im Editor-Sheet und in anderen Feldern und löschte die gewählte Sitzung → nur noch, wenn die Sitzungsliste selbst den Fokus hat und kein Sheet offen ist (Test `testDeleteFollowsListFocusAndSheets`).
- ⌘R während der S4-Rückfrage hätte ein zweites plink starten können → Menübefehle während eines Sheets gesperrt, zusätzlich Wächter in `reconnect` und `start` (Test `testDangerousSessionNeedsConfirmationOnEveryPath`: Liste, ⌘R und Abbrechen verbinden nie ohne Bestätigung).
- Texte aus Sitzungen ohne Sichtbarmachung (Liste, Tab-Titel, Hinweise) → überall `SessionWarning.visible` (S14/S4).
- „Verbinden“ im Editor nahm den Namen vor dem Umbenennen → verbindet nach dem Schließen mit dem aktuellen Namen (Test `testPendingConnectionFollowsRename`).
- Fokus sprang in Tabs, die gleich verbinden, in die Schnellverbindung → nur noch bei ⌘N/⌘T.
- Editor baute sich bei jedem Neuladen neu auf → nur bei echten Änderungen (Test `testRevisionChangesOnlyWithRealChanges`).
- Kein Weg gefunden, die Rückfrage (S4) zu umgehen. Die Bundle-ID mit deinem Namen ist die erlaubte Ausnahme.

**Offene Punkte – entschieden am 19.10.2026** (alle wie vorgeschlagen bzw. so belassen)
1. GSSAPI ganz abschalten (`-DPUTTY_GSSAPI=OFF` in `build-putty.sh`)? Kerberos braucht kaum jemand privat; dann entfiele das Laden fremder Bibliotheken grundsätzlich. **Entschieden: ja, in M3** zusammen mit der Anmeldung.
2. Export in einen vorhandenen PuTTY-Ordner überschreibt gleichnamige Sitzungen (der Sichern-Dialog fragt „Ersetzen?“) und setzt dessen Rechte auf 0700.
3. `RemoteCommand`, Agent- und Port-Weiterleitung: Hinweis beim Import und im Editor, aber keine Rückfrage vor jedem Verbinden (S4 verlangt die Warnung beim Öffnen fremder Sitzungen – bitte bestätigen).
4. `.reg`-Rundlauf ist für Werte, die kein UTF-8 sind, nicht byte-gleich (sie werden ersetzt); Ordner-Export ist byte-gleich.
5. Der Import liest auf dem Hauptthread (höchstens 16 MiB, linear).
6. Der Status „verbunden“ hängt am Sitzungsnamen: Wird eine verbundene Sitzung umbenannt, zeigt die neue Zeile bis zum Trennen „getrennt“ (im Code als Abkürzung vermerkt; sauber mit einer Kennung je Sitzung, wenn M4 sie braucht).
7. „Kann“-Punkt aus dem Review: Zählen der Verbindungen am Fenster mit echtem plink testen (heute nur am Modell getestet).

## 6. Reviews (Prüfer-Agenten)

- **ponytail-review:** 10 Befunde, alle umgesetzt außer „Testquellen doppelt“ (gelöst: nur noch das Erzeugerskript im Repo). Muss-Punkte: Absturz bei doppelten Dateinamen, Rückfrage bei Lesefehler, Editor nach ⌘Z – behoben. Außerdem: Tab Name→Gruppe, Proxy-Kette, alle Gefahren im Hinweis, Vorlage für Standardeinstellungen, `hexValue` einmal, Sortierung, Import/Export auch bei Terminalfenster vorne.
- **code-review** (zwei Achsen, mit swiftui-pro und vibe-security): K1 und M1–M6 umgesetzt (siehe 5.); N1, N2, N4–N6 umgesetzt; N3, N7 offen (5.); N8 (Platte lesen im `body`) bleibt – gelesen wird nur bei Auswahl- oder Bibliotheksänderung, eine Datei ≤ 1 MiB. Ermessensfragen (Tupel statt Typ, `SessionsModel.save` reicht durch) gelassen. Spec: Editor hat nur die häufigen Felder (so verlangt) plus Proxy-Abschnitt; Auth, Tunnel, Seriell folgen in den Meilensteinen dafür.
- **Gerüst B – Code-Review** (Prüfer-Agent, mit swiftui-pro und vibe-security): 13 Befunde, 12 umgesetzt (siehe 5.), einer offen als „Kann“ (5., Punkt 7). Doppelte Editor-Logik zusammengelegt (`editSelection`), veralteter Kommentar korrigiert.
- **Abweichung von M1:** Die Schnellverbindung ist kein eigenes Formular mehr, sondern das Feld oben in der Seitenleiste (⌘N öffnet ein neues Hauptfenster mit Fokus darin).

## 7. Skill-Protokoll

| Skill | Wann | Wofür |
|---|---|---|
| ponytail | Prüfphase (nachgeladen; die Regeln galten durchgehend) | kleinste Änderungen, Tests für neue Logik |
| mattpocock-skills:tdd | Prüfphase nachgeladen | Abgleich: je Scheibe erst Test (rot), dann Code; Seams aus dem Plan statt mit dir abgestimmt |
| mattpocock-skills:domain-modeling | Beginn | `docs/CONTEXT.md` (Sitzung, Gruppe, Standardeinstellungen, Import, Warnung, Gefährlich, Proxy-Sitzung), ADR 0001 |
| apple-skills:macos (AppKit) | Gerüst B | `NSSplitViewController` mit Sidebar-/Inspektor-Elementen, Werkzeugleiste mit Tracking-Separatoren, Fenster-Tabs, `sizingOptions = []` (RL 3.4 Regel 19) |
| apple-skills:swiftui + anthropic-skills:swiftui-pro | Oberfläche | `@Observable`, Sheets an der Seitenleiste, `contextMenu(forSelectionType:primaryAction:)`, `ContentUnavailableView.search`, Buttons mit Text |
| apple-skills:macos, swift, testing, design | Prüfphase nachgeladen | Abgleich Responder-Kette/Undo, Swift 6 (App mit MainActor-Standard), Swift Testing/XCTest, Texte |
| computer-use | vor der Oberflächenprüfung | Klick-Freigabe für die App (Terminal-App: nur Klicks) |
| anthropic-skills:vibe-security | Audit | Vertrauensgrenzen, Befunde in 5. |
| ponytail-review | Prüfer-Agent | Befunde in 6. |
| mattpocock-skills:code-review | Prüfer-Agent (mit swiftui-pro, vibe-security) | Befunde in 5./6. |

## 8. Hinweise für die nächsten Schritte

- `build/m2/ui.sh` kennt zusätzlich `gefahr`/`gefahr-weg` (Testsitzung mit `echo`-Proxy-Befehl für die Rückfrage).
- `build/skript.sh` zeigt jetzt auf `build/m2/ui.sh` (Schritt in `build/m2/schritt.txt`, nicht im Repo). `watch.sh` hasht `build/m2/*.sh` noch nicht – erst beim nächsten Neustart des Bauwächters ändern (eine laufende Schleife darf man nicht umschreiben); der Inhalt von `ui.sh` steht ohnehin in jedem `skript`-Log.
- Der Testserver (`build/m1/testserver.sh`) erzeugt bei jedem Start neue Schlüssel; plink fragt deshalb jedes Mal nach dem Hostschlüssel.
- Offen aus U1: GitHub-Umbenennung/Remote-URL, leerer alter Ordner in Application Support.
