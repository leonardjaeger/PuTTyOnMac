# Projektstand TunnelTerminal

**Stand:** 19.10.2026 · **Letzter abgenommener Schritt:** M2 Sitzungsverwaltung mit Oberflächen-Gerüst B „Werkbank“ (Tag `m2`, abgenommen am 19.10.2026, `docs/M2-Pruefliste.md`); davor U1 (Tag `u1`, Commit `642d38f`) und M1 (Tag `m1`, Commit `890b362`) · **Nächster:** M3 Schlüssel & Anmeldung

## Version und Bausteine

| Baustein | Stand |
|---|---|
| App | **TunnelTerminal** 0.1.1 (Build 2), Bundle-ID und Log-Subsystem `de.leonardjaeger.tunnelterminal` (Tests `….tests`), App-Icon „Tunnel“ aus `Design/Logo-Final/AppIcon.appiconset` (16/32 px Kleinfassung), macOS 14, Apple Silicon, Hardened Runtime, keine Sandbox (Plan 8.7) |
| Aufbau | `TunnelTerminal.xcodeproj`: App `TunnelTerminal` (AppKit + SwiftUI, Modul `TunnelTerminal`), Kern-Paket `TunnelTerminalCore` (ohne AppKit), Tests `TunnelTerminalCoreTests` (Swift Testing) und `TunnelTerminalTests` (XCTest) |
| PuTTY | 0.85 aus `Quellen/putty-0.85.tar.gz`, SHA-256 `13fd4db2936d03b73812a7bcc2a658e4dd29cc776a56c3670a7fc6f1a0ee8af8`, GPG „Release Key 2026“ (`1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5`), gebaut von `Scripts/build-putty.sh` nach `Contents/Helpers` (plink, pscp, psftp, puttygen) |
| PuTTY-Patch | `Scripts/putty-patches/0001-macos-pollhup-beim-verbinden.patch` (eine Zeile; plink hing bei abgewiesener Verbindung mit voller CPU). Bei jedem PuTTY-Update prüfen, ob noch nötig |
| SwiftTerm | 1.99.0 (exakt gepinnt), nur `TerminalView`; Prozess startet die App selbst (`posix_spawn`) |
| Oberfläche | Gerüst B „Werkbank“ (Plan 3.1): ein Hauptfenster (`NSSplitViewController`) mit Seitenleiste (Schnellverbindung ⇧⌘K, Suche, Sitzungen in Gruppen mit Status), Terminal in macOS-Fenster-Tabs, Inspektor „Verbindung“ (⌥⌘I); Editor als Sheet |
| Tests | 104 Kern-Tests (12 Suiten) + 46 App-Tests (5 Klassen), alle grün, ohne Compiler-Warnungen (Auftrag `m2Bt9`) |
| Daten | PuTTY-Ordner der App: `~/Library/Application Support/TunnelTerminal/putty` (0700/0600; in U1 aus dem Ordner des alten Arbeitstitels verschoben, der leere alte Ordner blieb stehen). Schnellsitzungen mit Präfix `TunnelTerminal-Schnell-`. Gruppen stehen im Sitzungsnamen („Gruppe/Titel“, ADR 0001). Dort liegen noch fünf Testsitzungen aus der M2-Prüfung (nur Platzhalter) |

## Bauen

- **Bauwächter:** `TunnelTerminal Bauwächter.command` im Terminal starten. Aufträge über `Scripts/go.sh <modus> <name>`; Modi `build`, `test` (erst `swift test` für den Kern, dann `xcodebuild test`), `kern`, `skript`, `log`. Auftragsnamen immer neu (`m2b1`, `m2t1` …), nur `A–Z a–z 0–9 _ -`.
- **Ablage:** `~/Library/Caches/TunnelTerminal-Build/` (außerhalb von iCloud): `waechter/requests`, `waechter/logs` (Log je Auftrag mit SHA-256 der Skripte, Status atomar), `DerivedData`, `CoreBuild`, `putty-0.85` (PuTTY-Cache mit Stempel aus Quelle, Patches und Bauskript). In der VM: `mnt/TunnelTerminal-Build`.
- **Zeitlimits:** `test` 30 min, `build` 20 min, `skript` 15 min, `kern` 10 min, sonst 2 min; bei Ablauf wird die ganze Prozessgruppe beendet.
- `skript` führt `build/skript.sh` aus, das zurzeit `build/m2/ui.sh` startet; der Schritt steht in `build/m2/schritt.txt` (nicht im Repo): `start` (Testserver + Debug-App), `stop`, `ordner` (Rechte im PuTTY-Ordner), `gefahr`/`gefahr-weg` (Testsitzung mit `echo`-Proxy-Befehl für die S4-Rückfrage). Für M3 auf `build/m3/` umstellen und die Ausnahme in `.gitignore` ergänzen. `watch.sh` hasht `build/m2/*.sh` noch nicht (beim nächsten Neustart des Bauwächters nachziehen). `build/u1/cmd.sh` (einmaliger Datenumzug U1) bleibt lokal; `build/m2/sicherung-vor-geruest-B.tgz` ebenso.
- `watch.sh` nach Änderungen neu starten (die laufende Schleife liest Änderungen nicht nach).
- **Xcode:** SwiftTerm bringt ein Build-Plugin mit; beim ersten Öffnen „Trust & Enable“. Der Bauwächter nutzt dafür `-skipPackagePluginValidation`.
- Auf dem Mac fehlt `gpg`; `build-putty.sh --gpg-pruefen` beim Versionswechsel (z. B. in der Cloud).
- Testserver für Anmeldetests ohne „Entfernte Anmeldung“: `build/m1/testserver.sh start|stop|status` (sshd nur auf 127.0.0.1:2222, nur Schlüssel, eigener ssh-agent).

## Entscheidungen aus M2 (19.10.2026)

- **Gerüst B jetzt statt am Ende** (Plan Entscheidung 10): Das eigene Fenster „Sitzungen“ ist in das Hauptfenster aufgegangen. Umgesetzt mit AppKit `NSSplitViewController` (Sidebar-/Inspektor-Elemente, Werkzeugleiste mit Tracking-Separatoren) statt `NavigationSplitView`/`.inspector` (Abweichung vom Plan), damit die Fenster-Tabs aus M1 und SwiftTerm unverändert bleiben.
- **GSSAPI wird in M3 abgeschaltet** (`-DPUTTY_GSSAPI=OFF` in `build-putty.sh`); bis dahin gilt `GSSCustom` als gefährlich (Rückfrage).
- So belassen: Export in einen vorhandenen PuTTY-Ordner überschreibt gleichnamige Sitzungen (nach „Ersetzen?“) und setzt 0700; `RemoteCommand`, Agent- und Port-Weiterleitung nur als Hinweis bei Import und im Editor, keine Rückfrage vor jedem Verbinden; `.reg`-Rundlauf für Nicht-UTF-8-Werte nicht byte-gleich; Import auf dem Hauptthread (≤ 16 MiB); Status „verbunden“ hängt am Sitzungsnamen (Kennung je Sitzung erst, wenn M4 sie braucht); Zählen der Verbindungen am Fenster mit echtem plink bleibt ein „Kann“-Test.
- Rückfrage (S4), Inspektor und plink lesen denselben PuTTY-Ordner wie die Seitenleiste (`SessionLibrary.directory`).

## Entscheidungen aus U1

- Umbenennung vor M2 vorgezogen (Plan Entscheidung 3), weil ab M3 Passwörter im Schlüsselbund an der Bundle-ID hängen. Name und feste Kennungen stehen in `AppIdentity` (Präfix der Schnellsitzungen leitet sich vom Namen ab).
- `.gitignore` schließt Plan und Arbeitsanweisungen als Muster aus (`*_Entwicklungsplan.md`, `*_Prompts.md`), dazu `__pycache__/` (S12, S14). Ins Repo kommt nur `Design/Logo-Final/` ohne `_alt-TunnelSSH/`.
- Offen vor der Weitergabe (M7): Markenprüfung des Namens; Release-Binary enthält noch Verweise auf DerivedData-Pfade (`/Users/…`) und `get-task-allow` – beim Archivieren/Notarisieren entfernen (S14).

## Entscheidungen aus M1

- **Echtheitsprüfung von plink bleibt an** (kein `-no-antispoof`): Nach Abfragen zeigt plink „Press Return to begin session“; Return genügt. Kein eigener Hinweis der App.
- **Trennen** (⌘., Menü „Verbindung“) schickt `SIGHUP`; das ist auch der Weg aus plinks Abfragen (Ctrl-C wirkt dort nicht, M0 B4).
- **Eingaben an plink blockieren nie:** Master nicht blockierend, Rest in einem Puffer bis 4 MiB, Nachlieferung über eine Schreibquelle.
- Telnet und Raw sind in der Schnellverbindung schon wählbar (Plan: M5); geprüft ist bisher nur Raw (Tests).

## Wichtige Erkenntnisse

Siehe `docs/M0-Machbarkeit.md` (B1–B18), `docs/M1-Recherche.md` (PuTTY-Fakten), `docs/M1-Pruefliste.md` und `docs/M2-Pruefliste.md` (Sicherheits-Audit: plink liest Zahlen wie `(int)strtol`, SSH-Proxy lädt weitere Sitzungen, `GSSCustom` per `dlopen`).
