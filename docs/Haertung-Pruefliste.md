# Härtung – Prüfliste: Sicherheitsprüfung vor der Weitergabe

**Stand:** 21.10.2026 · Version **1.0.0 (Build 4)** · **abgenommen am 21.10.2026** („abgenommen“, alle Vorschläge bestätigt), Tag `v1.0`
**Tests:** 221 Kern (28 Suiten, Swift Testing) + 113 App (XCTest), alle grün, ohne Compiler-Warnungen (Auftrag `hT6`
nach der letzten Änderung, vorher `hK9`/`hT5`; M7: 208 + 113). Übersprungen wie bisher nur die Bilder der Menü-Fenster und der pscp-Ende-zu-Ende-Test (brauchen eigene Läufe).
**Weitergabe:** `build/Weitergabe/TunnelTerminal-1.0.0.dmg` (3,3 MB, nur Apple-Chip), SHA-256
`56f2b3cb077d36b29fa6e40b4f551120bcd74815bd1a58eb6887582ee39661a4` (Auftrag `hD3`, nach der Abnahme mit der ergänzten
Kurzanleitung neu gebaut und geprüft, `hS7`; die abgenommene Fassung `b8b885dc…` unterschied sich nur darin; 0.9.0 hatte 5,3 MB).
**Ausgangsstand:** Tag `m7` (Commit `fe6e197`); zu Beginn ein roter Grundsatz-Test (siehe Befund N1).

## Was geprüft und geändert wurde

| # | Prüfpunkt (Plan „Härtung“) | Ergebnis |
|---|---|---|
| 1 | vibe-security-Audit des ganzen Codes gegen S1–S14 | eigenes Audit + zwei unabhängige Prüfer-Agenten (ganzer Code, dann die Korrekturen) + Code-Review Spec/Standards; Befunde unten, alle behoben oder zur Entscheidung |
| 2 | Robustheitstests: Sitzungsdatei, `.reg`, `ssh://` | neu `RobustnessTests` (Sitzungsdatei mit Auswertung und Zurückschreiben, `sshhostkeys`, Sitzungsnamen, Schnellverbindung, Profile – je 3000–4000 zufällig veränderte Eingaben, fester Startwert); `.reg`-Test läuft jetzt auch durch Importvorschau und Warnungen; `ssh://` hatte schon einen (M7). **Fund:** Port-Weiterleitungen gingen beim Zurückschreiben verloren (B6) |
| 3 | `gitleaks detect` über den ganzen Verlauf | gitleaks 8.28.0, alle 14 Commits: 2 Treffer = öffentliche GPG-Fingerabdrücke der PuTTY-Release-Schlüssel (`build/m0/02-tarball.sh`) → neu `.gitleaksignore`; danach 0 (Verlauf und Arbeitsstand) |
| 4 | S14 im Repo-Verlauf | alle Commits durchsucht: keine IP-Adressen außer Loopback/Dokumentationsbereich, keine E-Mail-Adressen außer Platzhaltern/noreply, keine `/Users/<name>`-Pfade, keine Heimserver-Adressen, kein Rechnername; Plan, Arbeitsanweisungen, Schlüssel und Sitzungsdateien nie eingecheckt; Git-Autor überall die noreply-Adresse. Die SVGs im Logo-Ordner tragen Anthropic-Herkunftsnachweise (C2PA) – ohne persönliche Angaben |
| 5 | S14 in der fertigen App (`strings` über alle Dateien des DMG) | `build/haertung/s14.sh dmg`: 0 × `/Users/`, Benutzername nur in der Bundle-ID, 0 × Rechnername, 0 private IP-Adressen, E-Mail-artige Texte nur SSH-Protokollnamen (`…@openssh.com`, `…@putty.projects.tartarus.org`); Copyright „Leonard Jäger“ |
| 6 | Keine Passwörter in `UserDefaults`, Protokoll, Absturzberichten | Laufzeitprüfung mit zufälligem Prüfwort im Schlüsselbund (`ui start`/`ui pruefen`): Verbindung über Debug-App, dann gesucht in Prozessliste, Umgebung von plink, PuTTY-Ordner, Einstellungen, Sitzungsprotokollen, Systemprotokoll (30 min, inkl. debug), Absturzberichten, Fensterzustand/Caches – **überall 0**. plink hat nur Terminal (0–2), die gelesene Passwort-Pipe (3), eigene Pipes und die TCP-Verbindung offen |
| 7 | Passwort-`CFData` überschreiben (aus M3) | nicht umgesetzt, Begründung als Entscheidung im Code (`Connection.swift`) – **zur Bestätigung** (E1) |
| 8 | Time-Profiler-Lauf (aus M7) | Release-Bau (nur zum Messen mit `get-task-allow`), 40 s mit Verbinden, neuem Tab, Fenstern „Schlüssel“/„Bekannte Hostschlüssel“, Seitenleiste/Inspektor: **keine Hänger**; längste Arbeit am Stück auf dem Hauptthread 83 ms (Layout eines neuen Tabs), 73 ms (Doppelklick → Verbinden). Im Debug-Bau ein Mikrohänger von 280 ms beim selben neuen Tab |
| 9 | Weitergabe (release-review) | Signatur ad hoc + Hardened Runtime an App und allen vier Hilfsprogrammen, keine Entitlements, Hilfsprogramme nur `libSystem`, Info.plist vollständig, Lizenzen im Paket, Gatekeeper lehnt ab (ohne Entwickler-ID erwartet; „Zuerst lesen“ erklärt „Dennoch öffnen“ ab macOS 15). **Fund:** App war universell (Intel + Apple-Chip), die PuTTY-Werkzeuge nur Apple-Chip (B9) |

## Befunde und Behebung

Ausführlich im Abschnitt „Sicherheits-Audit“. Kurz:

| # | Schwere | Befund | Behebung |
|---|---|---|---|
| B1 | **Kritisch** | `PreConnectCommand` und `AuthPlugin` startet plink 0.85 mit `/bin/sh` – keine Warnung, beim Import vorausgewählt, keine Rückfrage | Beide sind jetzt gefährlich wie der lokale Proxy-Befehl (Rückfrage vor jedem Verbinden und vor Übertragungen, beim Import nicht vorausgewählt), auch über Proxy-Sitzungen und Standardeinstellungen; `PreConnectCommand` so angezeigt, wie plink ihn ausführt |
| B2 | Hoch | Telnet-Proxy schickt vorgegebenen Text an einen beliebigen Dienst (auch auf dem Mac) | Rückfrage mit Ziel und ausgeschriebenem Text |
| B3 | Mittel | Proxy-Server oder entfernte Weiterleitung als Pfad = lokaler Unix-Socket | nicht verbinden, mit eigener Meldung |
| B4 | Mittel | Paketprotokoll mit `SSHLogOmitPasswords=0` schriebe das gespeicherte Passwort im Klartext | kein Passwort aus dem Schlüsselbund und keine Abfrage für Übertragungen in diesem Fall |
| B5 | Niedrig | Inspektor las `LogicalHostName`, PuTTY speichert `LogHost` | Schlüssel korrigiert (Tests, Doku) |
| B6 | Niedrig | Port-Weiterleitungen wie `AL80` und `L80` fielen beim Zurückschreiben zu einer zusammen | plinks Schlüssel bleibt erhalten |
| B7 | Niedrig | X11-Weiterleitung ohne Hinweis | Hinweis wie Agent-Weiterleitung (zu einem Pfad: B15) |
| B8 | Niedrig | Ordner-Import ohne Gesamtgrenze (Hauptthread) | höchstens 16 MiB wie `.reg` |
| B9 | Mittel | Release universell, PuTTY-Werkzeuge nur arm64: auf Intel-Macs startete die App, verbände aber nie | `ARCHS = arm64`, Prüfung im DMG-Skript |
| B10 | Niedrig | Zweite App-Instanz (z. B. aus der DMG oder als Test-Host) löschte beim Start/Ende die Schnellsitzungen der ersten | Aufräumen nur, wenn keine andere Instanz läuft |
| B11 | Niedrig | Kontextmenü: „Duplizieren“/„Löschen“ bei ungespeicherten Standardeinstellungen aktiv | ausgegraut nach denselben Regeln wie in der Menüleiste |
| B12 | **Hoch** (Prüfer 2) | Standardeinstellungen mit `Protocol=serial` als SSH-Proxy: die Ausnahmen für Seriell schalteten die Rückfrage zu B1/B2 ab – plink nimmt dort aber immer SSH | Standardeinstellungen als Proxy gelten als SSH |
| B13 | Mittel (Prüfer 2) | Paketprotokoll (`LogType` 3/4) schreibt – mit `LogFileClash=1` überschreibt – eine Datei, die die Sitzung bestimmt, ohne Rückfrage | Rückfrage vor jedem Verbinden |
| B14 | Niedrig (Prüfer 2) | Anmelde-Programm (`AuthPlugin`) bekäme das gespeicherte Passwort | kein Passwort aus dem Schlüsselbund mit `AuthPlugin` |
| B15 | Niedrig (Prüfer 2) | X11-Weiterleitung zu einer Anzeige als Pfad (`X11Display=/…`) = lokaler Socket | Rückfrage (keine Sperre, weil XQuartz so arbeitet) |
| N1 | – | Grundsatz-Test rot: das Aufräumskript aus M7 (`build/m7/versionen.sh`) enthält den alten Arbeitstitel | bleibt lokal (`.gitignore`, wie `build/u1/cmd.sh`) |

## So prüfst du

Geprüft mit der Testumgebung (Testserver 127.0.0.1:2222 nur mit Schlüssel, Sitzungen „Härtung/…“ nur mit Platzhaltern,
Debug-App mit dem letzten Bau). Nach der Abnahme mit `ui stop` aufgeräumt (Sitzungen, Schlüsselbund-Eintrag des
Prüfworts, eigene Hostschlüssel-Zeile, Testserver, Protokolle nur dieser Testsitzungen); `abschluss rest`: nichts übrig.

- [x] **„Härtung/Gefahr“** doppelklicken → Rückfrage „… tut beim Verbinden mehr als nur verbinden“ mit drei Punkten:
      Befehl `echo harmlos 127.0.0.1`, Telnet-Proxy mit Text `HELO test\u{D}\u{A}`, X11 zu `/tmp/…` → **Abbrechen**
      (Return) verbindet nicht; „Nicht verbunden.“
- [x] **„Härtung/Socket“** doppelklicken → „Nicht verbunden: Proxy oder entfernte Weiterleitung zeigt auf einen Pfad auf
      diesem Mac (lokaler Socket) – das verbindet die App nicht.“
- [x] **Import-Vorschau** (Ablage › Importieren › PuTTY-Ordner …, im Öffnen-Dialog ⇧⌘G und `~/Library/Caches/TunnelTerminal-Build/haertung-ui/import`): die Sitzung mit `PreConnectCommand`
      ist nicht vorausgewählt und zeigt die Warnung in Orange
- [x] **DMG 1.0.0 installieren** (Programme), erstes Öffnen nach „Zuerst lesen“, eine Sitzung verbinden
- [x] **Version:** TunnelTerminal › Über TunnelTerminal zeigt 1.0.0 (4)
- [x] **Kontextmenü** auf „Standardeinstellungen“ (Rechtsklick): „Duplizieren“ und „Löschen“ ausgegraut; auf einer
      Testsitzung beide aktiv
- [x] **In Xcode ⌘U:** alle Tests grün

## Code-Review (Spec und Standards, `mattpocock-skills:code-review`, Prüfer ohne eigenen Code)

Umfang `git diff m0..HEAD` (praktisch der ganze Code). 9 Befunde, keiner hoch. Die Richtlinien konnte der Prüfer nicht
selbst lesen (kein Projektzugriff); die Standards-Achse stützte sich auf S1–S14, `docs/Stand.md` und die im Code zitierten
Regeln.

| Befund | Schwere | Umgang |
|---|---|---|
| S-1 Passwort im Paketprotokoll (S1/S9) | mittel | behoben (B4) |
| S-2 Monospace außerhalb von Adressen/Fingerabdrücken/Terminal (Kürzel-Übersicht, öffentlicher Schlüssel, Schlüsseldatei, Befehle) | niedrig | **zur Entscheidung** (E4) |
| S-3 Doku/Kommentare veraltet (`CONTEXT.md`, README, Kommentar zu GSSAPI) | niedrig | behoben |
| R-1 Leser ohne Robustheitstest | mittel | behoben (`RobustnessTests`) |
| R-2 App-Tests bzw. zweite Instanz löschen Schnellsitzungen im echten PuTTY-Ordner | niedrig | behoben (B10) |
| R-3 Ordner-Import ohne Gesamtgrenze | niedrig | behoben (B8) |
| R-4 Rückfrage beim Beenden app-modal statt Sheet | niedrig | **so gelassen** (E5): beim Beenden gibt es oft kein Bezugsfenster; Terminal.app fragt ebenso |
| R-5 Kontextmenü graut nicht aus | niedrig | behoben (B11) |
| R-6 `private` fehlte an vier Stellen | niedrig | behoben (`fileprivate` bei der `RGB`-Erweiterung) |

Ohne Befund: `docs/Stand.md` stimmt mit dem Code, M0–M7/U1 umgesetzt oder als Abweichung abgenommen, Zahlen aus Dateien
überlauf- und indexsicher, Protokoll durchgehend mit `privacy:`, Kern ohne AppKit/MainActor, Menü enthält jeden
Symbolleisten-Befehl, `sizingOptions` gesetzt, Beschriftungen für VoiceOver, Schutz gegen Datenverlust.

## ponytail-review + vibe-security (Prüfer-Agenten, unabhängig)

**Erster Durchgang (ganzer Code, Stand `m7`):** 6 Befunde – B1 (kritisch), B2 (hoch), B3, B4 (mittel), B5, B7 (niedrig).
Der Prüfer hat PuTTY 0.85 im Quelltext gegengelesen; die Schlüsselnamen (`PreConnectCommand`, `AuthPlugin`, `LogHost`,
`X11Forward`, `SSHLogOmitPasswords`) und das Verhalten (`proxy/newmain.c`, `unix/network.c` „/“ = Unix-Socket) habe ich
am geprüften Tarball auf deinem Mac bestätigt. Schlankheit: `psftp` wird gebaut und ausgeliefert, aber nie benutzt (E3).

**Zweiter Durchgang (nur die Korrekturen):** 8 Befunde – B12 (hoch), B13 (mittel), B14, B15, Ordner-Grenze las weiter
(B8 nachgebessert), Kontextmenü „Löschen“ bei gespeicherten Standardeinstellungen fälschlich aus (B11 nachgebessert),
Aufräumen meines Prüfskripts hätte auch Protokolle anderer Sitzungen auf „…rtung“ erfasst (eingeschränkt auf die fünf
Testnamen; gelöscht wurden nur die drei Protokolle meiner Testsitzungen), README-Version. Alle behoben.
Bewusst zu streng (unschädlich): Proxy-Pfad trotz `ProxyLocalhost`/`ProxyExcludeList`, R-Weiterleitung auf einen Pfad
in einer Jump-Sitzung (plink entfernt sie dort ohnehin).

## Sicherheits-Audit (vibe-security, eigenes, ganzer Code)

Die Web-Abschnitte des Skills (Datenbank-Regeln, Zahlungen, JWT, CORS, Rate-Limits, KI-Schlüssel) treffen nicht zu: Die
App hat keinen Server, kein Konto und keine Netzwerkdienste außer plink/pscp. Übertragen: Geheimnisse, Eingaben an
Vertrauensgrenzen (Sitzungsdateien, Import, Links, Steuersequenzen, Ausgaben von pscp), Lieferkette, Weitergabe.

### Kritisch (behoben)

**`SessionWarning.swift` – Programmausführung über `PreConnectCommand`/`AuthPlugin` (B1).** Eine `.reg`-Datei eines
Bekannten oder ein PuTTY-Ordner mit `PreConnectCommand=<Befehl>` wurde ohne Warnung vorausgewählt importiert und beim
Verbinden ohne Rückfrage ausgeführt (`/bin/sh -c`). Das ist genau die Lücke, gegen die S4 schützt.

```swift
// Vorher
if let command = localProxyCommand { result.append(.localProxyCommand(command)) }
// Nachher (gekürzt)
if let command = localProxyCommand { result.append(.localProxyCommand(command)) }
if connectionProtocol != .serial {
    if let command = value(forKey: "PreConnectCommand"), !command.isEmpty {
        result.append(.preConnectCommand(expandedProxyCommand(command)))   // wie plink sie ausführt
    }
    if let command = value(forKey: "AuthPlugin"), !command.isEmpty { result.append(.authPlugin(command)) }
    if proxyKind == .telnet { result.append(.telnetProxy(server: …, text: expandedProxyCommand(proxyCommand))) }
}
// und als SSH-Proxy geladene Standardeinstellungen gelten immer als SSH (B12)
```

### Hoch (behoben)

- **Telnet-Proxy (B2):** vorgegebener Text an einen beliebigen Dienst, auch auf dem Mac → Rückfrage mit Ziel und Text.
- **Seriell-Ausnahme über Standardeinstellungen (B12):** umging B1/B2 → Standardeinstellungen als Proxy = SSH.

### Mittel (behoben)

- **Lokale Sockets (B3):** `ProxyHost=/…` oder `R…=/pfad:port` → nicht verbinden (`InputError.localSocket`).
- **Passwort im Paketprotokoll (B4):** mit `SSHLogOmitPasswords=0` kein Passwort aus dem Schlüsselbund.
- **Paketprotokoll überschreibt Dateien (B13):** Rückfrage vor jedem Verbinden.
- **Intel-Macs (B9):** Weitergabe nur noch arm64, Prüfung im DMG-Skript.

### Niedrig (behoben)

B5 (`LogHost`), B6 (Weiterleitungen beim Zurückschreiben), B7/B15 (X11), B8 (Ordner-Import), B10 (zweite Instanz),
B14 (`AuthPlugin` bekäme das Passwort).

### Geprüft ohne Befund

- **Geheimnisse:** gitleaks 0 (nach `.gitleaksignore`), keine Schlüssel/Token im Verlauf, Plan und Testsitzungen nie
  eingecheckt; Passwort nur Schlüsselbund → `writev` → Pipe fd 3, nie in Argumenten/Umgebung/Datei/Protokoll (Laufzeit:
  Prüfwort überall 0).
- **Prozessstart (S3, S8):** Argumentliste, keine Shell, `POSIX_SPAWN_CLOEXEC_DEFAULT`, nur 0–2 (+3), eigene Sitzung,
  umask 077; plink nur mit `-load`, pscp ohne `--`.
- **Sitzungsdateien (S4):** Leser wie `unix/storage.c`, Schreiber ohne CR/LF/NUL (Robustheitstest), Zahlen wie `strtol`.
- **Links (S6), Einfügen (S10), OSC 52/8 (S11):** unverändert aus M4/M7, Robustheitstest der Links grün.
- **Lieferkette (S7):** Tarball-Prüfsumme fest, GPG-Fingerabdruck, SwiftTerm exakt 1.99.0 (Commit des Tags).
- **Weitergabe (S8, S14):** ad hoc + Hardened Runtime überall, kein `get-task-allow`, keine Entitlements, keine Pfade oder
  Benutzernamen im Paket, Hilfsprogramme nur `libSystem`.

### Zusammenfassung

Ein kritischer und zwei hohe Befunde – alle an derselben Stelle: Die Liste der Sitzungseinstellungen, mit denen plink
lokal etwas startet oder anspricht, war gegenüber PuTTY 0.85 unvollständig. Die Liste ist jetzt vollständig (Tests je
Schlüssel, auch über Proxy-Sitzungen und Standardeinstellungen). Bei jedem PuTTY-Update gehört dieser Abgleich dazu.

## Entscheidungen bei der Abnahme (21.10.2026, alle Vorschläge bestätigt)

- **E1 – Passwort im Speicher (aus M3):** wird nicht überschrieben. Es ginge nur mit einer veralteten
  Schlüsselbund-Schnittstelle, Kopien in securityd, im Pipe-Puffer und in plink blieben; das Passwort lebt nur bis nach
  dem Start, Hardened Runtime ohne `get-task-allow` schützt den Speicher. Steht so im Code (`Connection.swift`).
- **E2 – Version 1.0.0 (Build 4)** für den Tag `v1.0`.
- **E3 – `psftp`** bleibt im Paket bis zu einem SFTP-Browser.
- **E4 – Monospace** bleibt an Kürzeln, öffentlichem Schlüssel, Schlüsseldatei und Befehlen; Plan 3.1 um „Schlüssel,
  Pfade, Befehle“ ergänzt.
- **E5 – Rückfrage beim Beenden** bleibt ein eigenes Fenster statt eines Sheets.
- **E6 – Telnet-Proxy** fragt vor jedem Verbinden nach.
- **E7 – Einfügen über macOS-Dienste** bleibt ohne Hinweisleiste; als bekannte Grenze in der Kurzanleitung (Abschnitt 4).
- **E8 – PuTTY-Fehler melden** (`POLLHUP`, Seriell-Zeilenmodus, `\` am Ende, ungesetzter Proxy-Wert, Proxy-Schleife,
  `--` in pscp) bleibt Empfehlung; die Meldungen formuliere ich auf Wunsch.
- **„Verbinden“ bei meiner ersten Prüfung:** Leonard hat selbst geklickt – kein Fehler der App.

## Nach der Abnahme

- **Kurzanleitung** (`Scripts/hilfe/Kurzanleitung.html` → `Kurzanleitung.rtf`): Einfügen über macOS-Dienste als bekannte
  Grenze (E7); Abschnitt „Sicherheit auf einen Blick“ war seit der Härtung zu knapp (nannte nur den lokalen
  Proxy-Befehl) und nennt jetzt alle Rückfragen und die Sperre für lokale Sockets. Danach Tests (`hT6`), DMG (`hD3`) und
  DMG-Prüfung (`hS7`: S14 sauber, Signaturen, arm64, Kurzanleitung im Paket = Quelle) wiederholt.
- **Vorfall beim Aufräumen:** `ui stop` beendete jede App-Instanz aus dem Bau-Cache – auch die Debug-App, in der Leonard
  gerade eine eigene Verbindung („Heimserver“) geöffnet hatte; deren plink lief ohne Fenster weiter. `ui.sh` beendet jetzt
  nur noch App-Instanzen aus dem Bau-Cache (nie eine installierte App) und keine, in der eine Verbindung außerhalb der
  Testsitzungen läuft. Neu `build/haertung/abschluss.sh` (Kurzanleitung, DMG-Prüfung, Reste-Prüfung, Commit, Push).
- Zwischenkopien der DMG (`…-vorher-….dmg`) entfernt; `TunnelTerminal-0.9.0.dmg` (M7) bleibt liegen.

## Noch nicht geprüft (kann ich nicht oder nicht sinnvoll)

- **DMG auf einem zweiten Benutzerkonto oder Mac** (aus M7) – bei dir.
- **Weg aus Safari** mit der installierten App (Standard-App festlegen, aus M7) – bei dir; `ssh://` öffnet weiter Termius.
- **VoiceOver mit dem Ohr** (aus M7) – bei dir; die Beschriftungen sind seit M7 vollständig.
- **Heimserver im Heimnetz** (aus M3, Abfrage „Lokales Netzwerk“) – bei dir. Nach der Abnahme stand eine Verbindung
  aus der Debug-App zum SSH-Port des Heimservers (TCP verbunden); Anmeldung und Passwort aus dem Schlüsselbund
  bestätigst du.
- **Time Profiler mit viel Ausgabe:** plink wartet nach der Anmeldung auf Return („Press Return to begin session“), und
  Tippen in der App ist für mich nicht freigegeben – der Durchsatz ist durch `ThroughputTests` und die Messung aus M4 belegt.

## Messwerte

| Messung | Wert |
|---|---|
| DMG | 3,3 MB (0.9.0: 5,3 MB, universell); App 7,3 MB |
| Hauptthread, Release (40 s, Time Profiler) | keine Hänger; längste Strecke 83 ms (Layout neuer Tab), 73 ms (Verbinden) |
| Hauptthread, Debug | ein Mikrohänger 280 ms (neuer Tab) |
| Kern-Tests | ≈ 3,5 s für alle 221, davon 19 000 neue zufällige Eingaben in den Robustheitstests |

## Skill-Protokoll

| Skill | Wofür | Was es geändert hat |
|---|---|---|
| ponytail (ganzer Chat, auch bei den Prüfern) | kleinste vollständige Lösung | vorhandene Warnliste erweitert statt neuer Mechanismus; Fehlerfall „lokaler Socket“ wie die bestehende Sperre; `PortForwarding` hält nur plinks Schlüssel; CFData bewusst nicht umgebaut |
| vibe-security | eigenes Audit, zwei Prüfer-Agenten | B1–B4, B12–B15; Laufzeitprüfung mit Prüfwort; gitleaks |
| ponytail-review | Prüfer-Agenten (ganzer Code, Korrekturen) | B1–B5, B7, B12–B15, Nachbesserungen an B8/B11 und am Prüfskript |
| mattpocock code-review | Spec/Standards seit `m0` (Prüfer) | S-1…S-3, R-1…R-6 |
| mattpocock tdd + apple-skills:testing | Test zuerst | neue Tests zuerst rot (Kompilierfehler bzw. Fehlschlag), dann grün; Robustheitstests mit festem Startwert |
| mattpocock diagnosing-bugs | Fund B6 | Schleife: Robustheitstest rot → Minimalfall `AL80`/`L80` → Regressionstest → Korrektur |
| apple-skills:release-review | DMG | Architektur-Fund B9, Prüfung im DMG-Skript, Version 1.0.0 |
| apple-skills:macos, apple-skills:swift | Grundlagen | `private`/`fileprivate`, `NSRunningApplication` für B10; nichts aus `macos-tahoe-apis/` |
| computer-use | eigene Oberflächenprüfung | Rückfragen „Gefahr“/„Socket“, Fenster und Leisten im Time-Profiler-Lauf |
| Nicht genutzt | `apple-skills:performance` | nicht als Skill geladen; Time Profiler direkt über `xctrace` (Vorgehen aus den Richtlinien 2.4/3.7) |
