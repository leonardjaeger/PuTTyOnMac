# Projektstand TunnelTerminal

**Stand:** 19.10.2026 · **Letzter abgenommener Schritt:** M3 Schlüssel & Anmeldung (Tag `m3`, abgenommen am 19.10.2026, `docs/M3-Pruefliste.md`); davor M2 (Tag `m2`, Commit `96e3a9b`), U1 (Tag `u1`, Commit `642d38f`) und M1 (Tag `m1`, Commit `890b362`) · **Nächster:** M4 Terminal-Komfort

## Version und Bausteine

| Baustein | Stand |
|---|---|
| App | **TunnelTerminal** 0.1.1 (Build 2), Bundle-ID und Log-Subsystem `de.leonardjaeger.tunnelterminal` (Tests `….tests`), App-Icon „Tunnel“ aus `Design/Logo-Final/AppIcon.appiconset` (16/32 px Kleinfassung), macOS 14, Apple Silicon, Hardened Runtime, keine Sandbox (Plan 8.7) |
| Aufbau | `TunnelTerminal.xcodeproj`: App `TunnelTerminal` (AppKit + SwiftUI, Modul `TunnelTerminal`), Kern-Paket `TunnelTerminalCore` (ohne AppKit), Tests `TunnelTerminalCoreTests` (Swift Testing) und `TunnelTerminalTests` (XCTest) |
| PuTTY | 0.85 ohne GSSAPI (`-DPUTTY_GSSAPI=OFF`, Bau bricht ab, falls `libgssapi` auftaucht) aus `Quellen/putty-0.85.tar.gz`, SHA-256 `13fd4db2936d03b73812a7bcc2a658e4dd29cc776a56c3670a7fc6f1a0ee8af8`, GPG „Release Key 2026“ (`1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5`), gebaut von `Scripts/build-putty.sh` nach `Contents/Helpers` (plink, pscp, psftp, puttygen) |
| PuTTY-Patch | `Scripts/putty-patches/0001-macos-pollhup-beim-verbinden.patch` (eine Zeile; plink hing bei abgewiesener Verbindung mit voller CPU). Bei jedem PuTTY-Update prüfen, ob noch nötig |
| SwiftTerm | 1.99.0 (exakt gepinnt), nur `TerminalView`; Prozess startet die App selbst (`posix_spawn`) |
| Oberfläche | Gerüst B „Werkbank“ (Plan 3.1): ein Hauptfenster (`NSSplitViewController`) mit Seitenleiste (Schnellverbindung ⇧⌘K, Suche, Sitzungen in Gruppen mit Status), Terminal in macOS-Fenster-Tabs, Inspektor „Verbindung“ und „Hostschlüssel“ (⌥⌘I); Editor als Sheet mit Abschnitt „Anmeldung“ (Schlüsseldatei, Passwort im Schlüsselbund); unten in der Seitenleiste „Schlüssel“ und „Bekannte Hostschlüssel“ (eigene Fenster, `ToolWindowController`); `AccentColor` Bernstein `#F2A33A` |
| Tests | 131 Kern-Tests (16 Suiten) + 65 App-Tests (8 Klassen), alle grün, ohne Compiler-Warnungen (Aufträge `m3k13`, `m3t9`) |
| Daten | PuTTY-Ordner der App: `~/Library/Application Support/TunnelTerminal/putty` (0700/0600; in U1 aus dem Ordner des alten Arbeitstitels verschoben, der leere alte Ordner blieb stehen). Schnellsitzungen mit Präfix `TunnelTerminal-Schnell-`. Gruppen stehen im Sitzungsnamen („Gruppe/Titel“, ADR 0001). Dort liegen noch fünf Testsitzungen aus der M2-Prüfung (nur Platzhalter). Passwörter im Anmelde-Schlüsselbund: Dienst `de.leonardjaeger.tunnelterminal.passwort`, Konto = Sitzungsname, gebunden an `benutzer@server:port` |

## Bauen

- **Bauwächter:** `TunnelTerminal Bauwächter.command` im Terminal starten. Aufträge über `Scripts/go.sh <modus> <name>`; Modi `build`, `test` (erst `swift test` für den Kern, dann `xcodebuild test`), `kern`, `skript`, `log`. Auftragsnamen immer neu (`m2b1`, `m2t1` …), nur `A–Z a–z 0–9 _ -`.
- **Ablage:** `~/Library/Caches/TunnelTerminal-Build/` (außerhalb von iCloud): `waechter/requests`, `waechter/logs` (Log je Auftrag mit SHA-256 der Skripte, Status atomar), `DerivedData`, `CoreBuild`, `putty-0.85` (PuTTY-Cache mit Stempel aus Quelle, Patches und Bauskript). In der VM: `mnt/TunnelTerminal-Build`.
- **Zeitlimits:** `test` 30 min, `build` 20 min, `skript` 15 min, `kern` 10 min, sonst 2 min; bei Ablauf wird die ganze Prozessgruppe beendet.
- `skript` führt `build/skript.sh` aus; es liest `build/m3/schritt.txt` (nicht im Repo) im Format „<skript> <schritt> [wert]“ und startet `build/m3/<skript>.sh`. `ui.sh`: `start` (Testserver + Testsitzung „M3-Test“ + Debug-App), `schluessel`, `sitzung-schluessel`, `neustart`, `zeige`, `kopf`, `gss`, `heim [adresse]` (Netz-Diagnose ohne Änderung am Server, Adresse maskiert), `stop`; dazu `machbarkeit.sh`, `probe.sh`. Für M4 auf `build/m4/` umstellen (Pfad in `build/skript.sh`, Ausnahme in `.gitignore`). `watch.sh` hasht `build/m*/*.sh` noch nicht (beim nächsten Neustart des Bauwächters nachziehen). `build/u1/cmd.sh` (einmaliger Datenumzug U1) bleibt lokal; `build/m2/sicherung-vor-geruest-B.tgz` ebenso.
- `watch.sh` nach Änderungen neu starten (die laufende Schleife liest Änderungen nicht nach).
- **Xcode:** SwiftTerm bringt ein Build-Plugin mit; beim ersten Öffnen „Trust & Enable“. Der Bauwächter nutzt dafür `-skipPackagePluginValidation`.
- Auf dem Mac fehlt `gpg`; `build-putty.sh --gpg-pruefen` beim Versionswechsel (z. B. in der Cloud).
- Testserver für Anmeldetests ohne „Entfernte Anmeldung“: `build/m1/testserver.sh start|stop|status` (sshd nur auf 127.0.0.1:2222, nur Schlüssel, eigener ssh-agent).

## Entscheidungen aus M3 (19.10.2026)

- **Passwort freiwillig im Editor sichern**, nicht „nach erfolgreicher Anmeldung“ (die App erkennt den Erfolg nicht, ohne mitzulesen – S2). Übergabe nur über Pipe `-pwfile /dev/fd/3` (`writev`); nicht bei Proxy, Telnet/Raw, ohne Benutzer, mit `SSHManualHostKeys`; an `benutzer@server:port` gebunden, Server/Benutzer genau wie plink (`prepare_session`).
- **Anmelde-Schlüsselbund** statt Datenschutz-Schlüsselbund (`-34018` ohne Team); nach jedem neuen Bau fragt macOS einmal. Mit Entwickler-Team wechseln (Test schlägt dann an).
- Passwort-`CFData` lässt sich nicht überschreiben (`shortcut:` in `Connection`) – in der Härtung prüfen. ⌘Z nach dem Löschen bringt die Sitzung ohne Passwort zurück.
- „Configured password was not accepted“ → „Ohne gespeichertes Passwort verbinden“ (nur bei Fehler-Ende); danach verbindet der Tab ohne Passwort weiter.
- **Kontrast `AccentColor`** (weiße Schrift auf Bernstein, ca. 2:1): bei der Abnahme so belassen, in M7 messen.
- Ed448/DSA-Hostschlüssel ohne Fingerabdruck; `GSSCustom` bleibt als Hinweis.
- **Port wie plink:** `PortNumber` gilt nur mit bekanntem `Protocol`, sonst 22.
- **Für M4 notiert:** Während plink die Netzverbindung aufbaut, bleibt das Terminal leer und der Inspektor zeigt schon „Verbunden“ – in der Statuszeile „Verbinde …“ zeigen.

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

Siehe `docs/M0-Machbarkeit.md` (B1–B18), `docs/M1-Recherche.md` (PuTTY-Fakten), `docs/M1-Pruefliste.md` `docs/M2-Pruefliste.md` (Sicherheits-Audit: plink liest Zahlen wie `(int)strtol`, SSH-Proxy lädt weitere Sitzungen, `GSSCustom` per `dlopen`), `docs/M3-Recherche.md` (puttygen ohne Terminal, Format von `sshhostkeys` und Fingerabdruck, Port und Server wie plink, Schlüsselbund) und `docs/M3-Pruefliste.md` (Sicherheits-Audit M3).
