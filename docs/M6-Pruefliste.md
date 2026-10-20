# M6 – Prüfliste: Dateiübertragung

**Stand:** 20.10.2026 · Version 0.1.1 (Build 2) · abgenommen am 20.10.2026 („passt“), Tag `m6`
**Messungen:** `docs/M6-Machbarkeit.md` · **Tests:** 195 Kern (25 Suiten, Swift Testing) + 99 App (12 Klassen, XCTest),
alle grün, ohne Compiler-Warnungen (Aufträge `m6k15`, `m6t3`). Übersprungen wird dort nur der Ende-zu-Ende-Test mit dem
eingebauten pscp gegen den Testserver; er läuft eigens und ist ebenfalls grün (`m6e3`).

## Was neu ist

- **Hochladen** über pscp (SFTP) mit der Sitzung des Tabs: Dateien aufs Terminal ziehen, auf die Ablagefläche im
  Inspektor-Abschnitt „Dateien“ ziehen oder anklicken, Symbolleisten-Knopf „Hochladen“ bzw. Verbindung › „Dateien
  hochladen …“. Danach ein Sheet mit dem **Zielordner auf dem Server** (leer = persönlicher Ordner, „~/“ vorn erlaubt).
  Die App listet den Zielordner vorher: Gibt es ihn nicht → Meldung (pscp hätte sonst eine Datei mit dem Ordnernamen
  angelegt); gibt es gleichnamige Dateien → **Rückfrage „Ersetzen?“**. Der Vergleich ignoriert Groß-/Kleinschreibung
  (ein Mac als Server ersetzt „Readme.txt“, wenn „README.txt“ kommt). Ist der Ordner riesig (Liste über 16 MB), fragt die
  App für jede Datei. Danach je Datei ein Lauf mit Fortschritt.
  Abgelehnt werden: Ordner, Namen mit „\“ (pscp würde den Namen kürzen), zwei Dateien gleichen Namens in einem Auftrag.
- **Herunterladen** (Inspektor „Herunterladen …“ bzw. Verbindung › „Datei herunterladen …“): Pfad der Datei auf dem Server
  eingeben, dann im Sichern-Dialog Ort und Namen wählen. Vorgeschlagen ist der letzte Teil des Pfads; „/“, „.“, „..“ und
  Steuerzeichen kommen darin nicht vor. Der Sichern-Dialog fragt selbst vor dem Ersetzen. pscp schreibt in eine **versteckte
  Teildatei** daneben. Erst nach Erfolg ersetzt sie die Zieldatei; bei Abbruch oder Fehler ist sie sofort weg, eine
  vorhandene Datei bleibt dann unverändert. Die Datei bekommt die Rechte 0600 (nie „ausführbar“, auch wenn sie es auf dem
  Server ist) und wird wie ein Download aus Safari markiert (Gatekeeper prüft Programme daraus beim ersten Öffnen).
  Danach „Im Finder zeigen“.
- **Fortschritt und Abbrechen** im Inspektor (er blendet sich beim Start ein), auch Verbindung › „Übertragung abbrechen“.
  Bricht man beim Hochladen ab, sagt die App, dass auf dem Server eine unvollständige Datei liegt (pscp räumt sie nicht
  auf). Tab schließen oder App beenden während einer Übertragung → Rückfrage, dann Abbruch.
- **Anmeldung:** Schlüssel bzw. Agent wie im Terminal; gespeichertes Passwort aus dem Schlüsselbund wie bei plink. Verlangt
  der Server ein Passwort, fragt die App **einmal** (nur für diese Übertragung, nicht gespeichert, nur über die Pipe).
  Nennt die Sitzung keinen Benutzer, fragt das Sheet danach (pscp nähme sonst still den Benutzer dieses Macs).
  Unbekannter oder geänderter Hostschlüssel → Meldung „zuerst im Terminal verbinden“ (pscp nimmt nichts an).
  Sitzungen mit lokalem Proxy-Befehl → dieselbe Rückfrage wie vor dem Verbinden. Server mit nur einem Zeichen im Namen
  lehnt die App mit einer Erklärung ab (pscp hielte „x:pfad“ für ein Laufwerk).
- Nur bei SSH (Telnet, Raw, Seriell: kein Abschnitt „Dateien“, Befehle grau) und **nur während einer Verbindung**
  („Nur während einer Verbindung.“ im Inspektor, Befehle grau). Die Übertragung nutzt die Sitzung, mit der das Terminal
  gestartet ist; Änderungen im Editor gelten wie bei Tunneln erst ab dem nächsten Verbinden.
- **Aufgeräumt (Notiz aus M5):** Symbolleiste in `WorkbenchToolbar`, Import/Export in
  `ConnectionWindowController+Import.swift`, die Übertragung in `FileTransferController`. Der Fenster-Controller hat jetzt
  727 statt 774 Zeilen, trotz M6. Die Menüprüfung blieb im Controller (Begründung unten).

## So prüfst du

Die Testumgebung läuft: Testserver 127.0.0.1:2222 (nur Schlüssel; SFTP beginnt dort im Testordner „fern“ statt in deinem
persönlichen Ordner), Sitzung „M6/Mac“ in der Debug-App (neu gestartet mit dem letzten Build). Zwei Finder-Fenster sind
offen: „lokal“ (Testdateien zum Ziehen, klein und 400 MB) und „fern“ (die Server-Seite, mit `vom-server.txt`, `gross.bin`
und einem leeren `unterordner`). Nach der Abnahme räume ich mit `ui stop` auf.

- [ ] „M6/Mac“ verbinden. Inspektor, Abschnitt „Dateien“: Ablagefläche und „Herunterladen …“; Symbolleiste „Hochladen“
      (Pfeil-Dokument, nicht das Teilen-Symbol) ist aktiv
- [ ] `klein.txt` aus „lokal“ **aufs Terminal ziehen** → Sheet „„klein.txt“ hochladen“, Zielordner leer lassen →
      „Hochladen“ → Inspektor „„klein.txt“ hochgeladen in den persönlichen Ordner.“; im Terminal `ls -l` → Datei da
      (der persönliche Ordner des Testservers ist „fern“)
- [ ] Dieselbe Datei noch einmal auf die **Ablagefläche** ziehen → Rückfrage „„klein.txt“ gibt es im Zielordner schon.“ →
      „Abbrechen“ → „Nicht hochgeladen.“
- [ ] `gross.bin` (400 MB) hochladen, Zielordner `unterordner`, während des Fortschritts „Abbrechen“ → „Abgebrochen. Auf
      dem Server liegt eine unvollständige „gross.bin“.“ (in „fern › unterordner“ kleiner als 400 MB)
- [ ] Noch einmal `klein.txt` hochladen, diesmal umbenannt in `KLEIN.TXT` (Finder) → Rückfrage, denn der Mac als Server
      unterscheidet Groß-/Kleinschreibung nicht
- [ ] „Herunterladen …“ → Pfad `vom-server.txt` → „Weiter …“ → Sichern-Dialog schlägt „vom-server.txt“ vor → in „lokal“
      sichern → „„vom-server.txt“ geladen.“, „Im Finder zeigen“ markiert sie
- [ ] Noch einmal herunterladen, gleicher Ort → der Sichern-Dialog fragt „Ersetzen?“
- [ ] `gross.bin` herunterladen und während des Fortschritts abbrechen → „Abgebrochen – auf dem Mac ist nichts geändert.“,
      im Finder keine Teildatei (auch nicht mit ⇧⌘. für versteckte Dateien)
- [ ] Pfad `/gibt/es/nicht.txt` herunterladen → Fehler in Rot („unable to identify …: no such file or directory“)
- [ ] Optional, falls „Entfernte Anmeldung“ bei dir ohnehin an ist: Sitzung `localhost` ohne gespeichertes Passwort →
      beim Übertragen fragt die App einmal nach dem Passwort; Sitzung ohne Benutzer → das Sheet fragt nach dem Benutzer
- [ ] Optional: Heimserver im Heimnetz, Datei hoch- und herunterladen
- [ ] In Xcode ⌘U: alle Tests grün

## Code-Review (Standards und Spec, zwei getrennte Prüfer)

**Behoben:**
- *Spec:* Übertragungen nur noch im verbundenen Fenster (Plan: „In einem verbundenen Fenster“); vorher ging es auch nach
  dem Trennen.
- *Spec:* Die Übertragung nutzt die Sitzung vom Verbindungsstart, nicht den inzwischen geänderten Editorstand.
- *Spec:* Die Ordnerliste wurde bei 16 KB abgeschnitten, große Ordner wären still überschrieben worden. Jetzt eigene
  Grenze, bei Überlauf fragt die App für jede Datei.
- *Spec:* Zwei gleichnamige Dateien in einem Auftrag werden abgelehnt.
- *Standards 3.4:* Symbole Pfeil-Dokument statt Teilen-Symbol; eindeutige Knöpfe im Schließen-Dialog („Übertragung
  beenden“ / „Weiter übertragen“); „Weiter …“ im Öffnen-Dialog; Fehler in Rot über `ErrorText`.
- *Standards 3.2:* Robustheitstest für die neuen Leser (Zufallsausgabe); alles Private `private`; lange Ausdrücke
  aufgeteilt; ungenutztes `isRunning` im Modell entfernt; der erfragte Benutzer geht durch `setUserName` (S3).

**Bewusst nicht geändert:**
- *Regel 19:* Das Sheet-Fenster nutzt `sizingOptions = .standardBounds`, damit es der Fehlerzeile folgt. Regel 19 meint
  SwiftUI im Split-View des Fensters; dort bleibt `[]`. Im Code begründet.
- *Fenster-Controller:* weiterhin über 700 Zeilen. Die Menüprüfung herauszulösen hätte `private` aufweichen müssen
  (Regel 3.2.4). Vorschlag: in M7 zusammen mit der nächsten Menüänderung.
- *Ermessensfragen (Fowler):* Die pscp-Fabriken haben dieselben fünf Parameter („Data Clump“). Hoch- und Herunterladen
  beginnen ähnlich. `uploads == nil` unterscheidet im Sheet die beiden Fälle. `showsTunnels` heißt eigentlich „ist SSH“.
  Jede Zusammenlegung wäre mehr Code als jetzt.

## ponytail-review (Prüfer-Agent, unabhängig, zwei Durchgänge)

Erster Durchgang (auf dem Stand vor dem Code-Review):
1. *Muss:* große Zielordner werden still überschrieben → war schon behoben, siehe oben.
2. *Muss:* Server ohne Groß-/Kleinschreibung (Mac, Windows) werden still überschrieben → **behoben** (Kerntest, E2E).
3. *Sollte:* doppelte Namen in einem Auftrag → war schon behoben; im zweiten Durchgang auch ohne Groß-/Kleinschreibung.
4. *Wäre schön:* Server mit einem Zeichen → **behoben** (Kerntest).
5. *Wäre schön:* ungenutztes `isRunning` → war schon behoben; doppelte Schlüsselbund-Abfrage bleibt (siehe unten).
6. *Nicht geprüft:* Umlaute in der Ordnerliste → jetzt im E2E-Test („Grüße.txt“ zweimal hochladen → Rückfrage). Grün.

Zweiter Durchgang (Nachprüfung der Korrekturen):
- Die Ordnerliste wurde für jeden Namen neu zerlegt, auf dem Hauptthread → **behoben**: `PscpOutput.existing` zerlegt
  einmal und läuft mit `@concurrent` außerhalb (RL 3.7). Bei einer übergroßen Liste kürzt die App jetzt einmal auf die
  letzten 16 KB, statt bei jedem Block Megabytes zu verschieben.
- Die doppelte Schlüsselbund-Abfrage (`storedPasswordForTransfer`) ist vertretbar: Die Regel liegt im Kern, zusammengelegt
  wären es nur 2 Zeilen weniger.
- Verschobener Doc-Kommentar in `Connection.swift` → behoben.
- Endet die Verbindung, während der Öffnen- oder Sichern-Dialog offen ist, startet die Übertragung trotzdem. Die App
  lässt das so: pscp meldet sich selbst an, nimmt keinen Hostschlüssel an (S5) und nutzt die Sitzung vom Start.

## Sicherheits-Audit (vibe-security)

Pfade, Namen und Texte vom Server sind Eingaben von außen. Geprüft wurde der ganze M6-Code, dazu pscp 0.85 im Quelltext
(pscp.c, cmdline.c, wildcard.c, console.c).

**Nicht zutreffend** (keine Web-App): Datenbank-Zugriff/RLS, Web-Anmeldung (JWT, Middleware, Server Actions),
Rate-Limits, Zahlungen, Mobil, KI/LLM, Web-Deployment.
**Geheimnisse:** keine im Diff. Gesucht wurde nach Schlüsselmustern, privaten IP-Adressen und `/Users/`; zusätzlich laufen
die Grundsatztests (kein `-pw`, Schlüsselbund nur in `PasswordStore.swift`, nur Dokumentations-Adressen, S12/S14).

### Kritisch
Keine.

### Hoch
Keine.

### Mittel (alle behoben)

**`FileTransferController.swift` performUpload – stiller Datenverlust auf dem Server in großen Ordnern**
Die Rückfrage stützte sich auf `pscp -ls`, behalten wurden aber nur 16 KB der Ausgabe (etwa 210 Einträge). Eine vorhandene
Datei weiter vorn im Ordner wurde ohne Frage überschrieben (pscp öffnet mit `TRUNC`).
```swift
// Vorher
let listing: String = try await pscp(job) { … PscpCommand.list(…) }
let existing: [String] = names.filter { PscpOutput.listing(listing, contains: $0) }
// Nachher
let listing: (output: String, complete: Bool) = try await pscp(job, limit: Self.listingLimit) { … }
let existing: [String] = listing.complete ? await PscpOutput.existing(names, in: listing.output) : names
```

**`FileTransfer.swift` PscpOutput – stiller Datenverlust auf Servern ohne Groß-/Kleinschreibung**
Ein Mac oder Windows als Server: „Bericht.pdf“ ersetzt ein vorhandenes „bericht.pdf“, die App fragte aber nicht.
```swift
// Vorher
line.hasSuffix(" " + name)
// Nachher
let options: String.CompareOptions = [.caseInsensitive, .anchored, .backwards]   // nur das Zeilenende
lines.contains { $0.range(of: ending, options: options) != nil }
```

**`FileTransferController.swift` performUpload – zwei gleichnamige Dateien in einem Auftrag**
Aus zwei Ordnern gewählt (z. B. Suchergebnis) ersetzte die zweite still die erste; die Meldung sagte „2 Dateien
hochgeladen“.
```swift
// Vorher: keine Prüfung
// Nachher
var seen: Set<String> = []
if let twice = names.first(where: { !seen.insert($0.lowercased()).inserted }) { report("Nicht hochgeladen: Zwei Dateien heißen …") }
```

### Niedrig

**`FileTransferController.swift` performDownload – geladene Datei behielt „ausführbar“ vom Server (behoben)**
pscp übernimmt die Rechte vom Server (umask 077: aus 0755 wird 0700). Ein kompromittierter Server konnte eine
ausführbare Datei ohne Endung liefern, ein Doppelklick im Finder startet sie im Terminal. Die Quarantäne-Markierung
fängt das meist ab, deshalb nur „niedrig“.
```swift
// Vorher
guard rename(part.path, target.path) == 0 else { … }
// Nachher
guard chmod(part.path, 0o600) == 0, rename(part.path, target.path) == 0 else { … }
```

**Offen, bewusst so:**
- Ein eingegebenes Passwort liegt bis zum Ende der Übertragung als `Data` im Speicher und wird nicht überschrieben.
  Das ist derselbe `shortcut` wie beim gespeicherten Passwort seit M3 (Kommentar in `Connection.swift`), Härtung später.
- Nach einem abgebrochenen Hochladen bleibt die unvollständige Datei auf dem Server. Die App sagt das; löschen kann
  pscp nicht (dafür bräuchte es psftp).

### Geprüft ohne Befund
- **Ablageort auf dem Mac:** Das Ziel ist immer eine Datei, kein Ordner. pscp schreibt deshalb nur dorthin und übernimmt
  keinen Namen vom Server (pscp.c `destfname = targ`). Den Namen bestimmt die App aus dem eingegebenen Pfad
  (`RemotePath.localFileName`, ohne „/“, „..“, Steuerzeichen), den Ort wählt der Sichern-Dialog. Joker im Pfad werden
  maskiert, genau passend zu `wc_unescape`. Ohne `-r` werden keine Ordner geholt.
- **Texte vom Server** (Banner, Fehlermeldungen, Ordnerzeilen) werden nur verglichen oder über `visible()` angezeigt:
  Steuer- und Formatzeichen (auch Richtungswechsel U+202E) sichtbar, Meldung höchstens 300 Zeichen. Speicher begrenzt
  (16 KB je Lauf, 16 MB für die Ordnerliste).
- **S1:** Passwort nur über `-pwfile /dev/fd/3` (pscp liest es erst nach `-load`). Aus dem Schlüsselbund nur bei
  passendem Ziel. Nie mit Proxy oder festen Hostschlüsseln. Nie gespeichert.
- **S3:** Argumentliste ohne Shell, Sitzung über `-load`. Server geprüft, IPv6 in Klammern. Lokale Pfade absolut. Kein
  `--` (pscp-0.85-Fehler bestätigt). Der Benutzer geht durch dieselbe Prüfung wie im Editor.
- **S4:** Rückfrage bei lokalem Proxy-Befehl auch vor pscp (getestet).
- **S5:** `-batch` nimmt Hostschlüssel nie an (console.c).
- **S8/S9/S14:** Start über `TerminalProcess`; im Protokoll steht nur, ob ein Fehler auftrat; keine persönlichen Daten.
- **Aufräumen:** Die Teildatei verschwindet bei Abbruch, Fehler, Tab-Schließen und App-Ende. Die vorübergehende Sitzung
  wird nach jedem Lauf sowie beim Start und Ende der App entfernt.

### Zusammenfassung
Drei stille Überschreibungen (mittel) und die Rechte geladener Dateien (niedrig) sind behoben und getestet, zum Teil mit
dem echten pscp. Offen ist nur das nicht überschriebene Passwort im Speicher, wie seit M3.

## Für dich zu entscheiden

1. **Passwort-Abfrage beim Übertragen** geht über den Plan hinaus. Ohne sie gingen Übertragungen nur mit Schlüssel, Agent
   oder gespeichertem Passwort. Behalten (mein Vorschlag) oder streichen?
2. **Fenster-Controller weiter aufteilen** (Menüprüfung) in M7? Dann notiere ich es im Plan.

**Entschieden bei der Abnahme (20.10.2026):** Beide Vorschläge angenommen – die Passwort-Abfrage bleibt, das weitere
Aufteilen des Fenster-Controllers ist für M7 notiert.

## Noch nicht geprüft (kann ich nicht oder nicht sinnvoll)

- **Ziehen und Ablegen, Tippen im Sheet, Sichern-Dialog, Fortschritt und Abbrechen mit der Maus:** Computer-Use darf
  TunnelTerminal nur anklicken. Die Abläufe decken App-Tests und der E2E-Test ab; mit der Maus prüfst du sie oben.
- **Server über IPv6** und ein **echtes Passwort über `-pwfile` mit pscp:** nicht gemessen; der Testserver nimmt nur
  Schlüssel. Bei plink ist beides gemessen (M1/M3), pscp nutzt denselben Code.
- **Heimserver:** nicht angefasst (nur nach deiner Zusage).

## Skill-Protokoll

| Skill | Wofür | Was es geändert hat |
|---|---|---|
| ponytail (ganzer Chat) | kleinste vollständige Lösung | kein SFTP-Browser, kein `-r`, kein psftp, keine Wiederaufnahme, keine gemerkten Zielordner je Sitzung (nur je Tab) |
| vibe-security | eigenes Audit, Prüfer-Agent | Rechte 0600, Texte vom Server sichtbar und gekürzt, Name nie vom Server |
| ponytail-review | Prüfer-Agent, zwei Durchgänge | Groß-/Kleinschreibung, ein-Zeichen-Server, Auswertung außerhalb des Hauptthreads |
| code-review (mattpocock) | Standards- und Spec-Prüfer getrennt | nur verbunden, Startsitzung, Ordnerliste ohne Abschneiden, Symbole, Dialogknöpfe |
| apple-skills:macos, :swift | AppKit-Sheets, Öffnen/Sichern-Dialog, Nebenläufigkeit | `withCheckedContinuation` um `TerminalProcess`, `@concurrent` für die Ordnerliste, `Sendable`-Ergebnisse |
| apple-skills:design | Fortschritt, Ersetzen-Rückfrage, Texte | „Ersetzen“ als zerstörerischer Knopf, Ergebnis im Inspektor statt Hinweisfenster, VoiceOver-Ansage |
| swiftui / swiftui-pro | Inspektor-Abschnitt, Sheets | `Button` mit Text und Symbol, `foregroundStyle`, Aktionen als Methoden |
| apple-skills:testing + mattpocock:tdd | Tests | siehe unten |
| anthropic-skills:computer-use | eigener UI-Check | nur Klicks (Stufe „click“): Abschnitt „Dateien“, Symbolleiste, Herunterladen-Sheet mit Prüfmeldung, Abbrechen, Öffnen-Dialog |

**TDD, ehrlich:**
- Kern: rot → grün, ein Test nach dem anderen (Pfade, pscp-Aufruf, Ausgabe-Leser, Robustheit). Die Korrekturen aus den
  Reviews ebenfalls rot → grün: Groß-/Kleinschreibung (`m6k8` rot, `m6k9` grün), Server mit einem Zeichen (`m6k11` rot,
  `m6k12` grün), `existing` (`m6k13` rot, `m6k14` grün).
- App: Die Ablauf-Tests mit dem nachgebauten pscp sind erst **nach** der Umsetzung entstanden. Zum Ausgleich habe ich
  absichtlich gebrochen: Ohne `removePartFile` scheitert testCancelledDownloadKeepsOldFile. Danach wieder rot → grün:
  Rechte 0600 (`m6a4` rot, `m6a5` grün), doppelte Namen ohne Groß-/Kleinschreibung (`m6a8` rot, `m6a9` grün).
- Seams (vorher festgelegt): `RemotePath`, `PscpCommand`, `PscpOutput` im Kern; in der App `FileTransferController`
  mit austauschbarem pscp-Pfad und `TransferPrompts`.
