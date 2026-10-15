# Projektstand SSH-App

**Stand:** 15.10.2026 · **Letzter abgenommener Meilenstein:** M1 Fundament (Tag `m1`, abgenommen am 15.10.2026, `docs/M1-Pruefliste.md`) · **Nächster:** M2 Sitzungsverwaltung

## Version und Bausteine

| Baustein | Stand |
|---|---|
| App | 0.1.0 (Build 1), Bundle-ID `de.leonardjaeger.sshapp`, macOS 14, Apple Silicon, Hardened Runtime, keine Sandbox (Plan 8.7) |
| Aufbau | `SSHApp.xcodeproj`: App `SSH-App` (AppKit + SwiftUI, Modul `SSHApp`), Kern-Paket `SSHAppCore` (ohne AppKit), Tests `SSHAppCoreTests` (Swift Testing) und `SSHAppTests` (XCTest) |
| PuTTY | 0.85 aus `Quellen/putty-0.85.tar.gz`, SHA-256 `13fd4db2936d03b73812a7bcc2a658e4dd29cc776a56c3670a7fc6f1a0ee8af8`, GPG „Release Key 2026“ (`1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5`), gebaut von `Scripts/build-putty.sh` nach `Contents/Helpers` (plink, pscp, psftp, puttygen) |
| PuTTY-Patch | `Scripts/putty-patches/0001-macos-pollhup-beim-verbinden.patch` (eine Zeile; plink hing bei abgewiesener Verbindung mit voller CPU). Bei jedem PuTTY-Update prüfen, ob noch nötig |
| SwiftTerm | 1.99.0 (exakt gepinnt), nur `TerminalView`; Prozess startet die App selbst (`posix_spawn`) |
| Tests | 39 Kern-Tests (5 Suiten) + 14 App-Tests, alle grün (Auftrag `m1t14`) |

## Bauen

- **Bauwächter:** `SSH-App Bauwächter.command` im Terminal starten. Aufträge über `Scripts/go.sh <modus> <name>`; Modi `build`, `test` (erst `swift test` für den Kern, dann `xcodebuild test`), `kern`, `skript`, `log`. Auftragsnamen immer neu (`m2b1`, `m2t1` …), nur `A–Z a–z 0–9 _ -`.
- **Ablage:** `~/Library/Caches/SSH-App-Build/` (außerhalb von iCloud): `waechter/requests`, `waechter/logs` (Log je Auftrag mit SHA-256 der Skripte, Status atomar), `DerivedData`, `CoreBuild`, `putty-0.85` (PuTTY-Cache mit Stempel aus Quelle, Patches und Bauskript). In der VM: `mnt/SSH-App-Build`.
- **Zeitlimits:** `test` 30 min, `build` 20 min, `skript` 15 min, `kern` 10 min, sonst 2 min; bei Ablauf wird die ganze Prozessgruppe beendet.
- `skript` führt `build/skript.sh` aus, das `build/m1/cmd.sh` zeigt und startet (Inhalt steht im Log). Für M2 auf `build/m2/` umstellen.
- `watch.sh` nach Änderungen neu starten (die laufende Schleife liest Änderungen nicht nach).
- **Xcode:** SwiftTerm bringt ein Build-Plugin mit; beim ersten Öffnen „Trust & Enable“. Der Bauwächter nutzt dafür `-skipPackagePluginValidation`.
- Auf dem Mac fehlt `gpg`; `build-putty.sh --gpg-pruefen` beim Versionswechsel (z. B. in der Cloud).
- Testserver für Anmeldetests ohne „Entfernte Anmeldung“: `build/m1/testserver.sh start|stop|status` (sshd nur auf 127.0.0.1:2222, nur Schlüssel, eigener ssh-agent).

## Entscheidungen aus M1

- **Echtheitsprüfung von plink bleibt an** (kein `-no-antispoof`): Nach Abfragen zeigt plink „Press Return to begin session“; Return genügt. Kein eigener Hinweis der App.
- **Trennen** (⌘., Menü „Verbindung“) schickt `SIGHUP`; das ist auch der Weg aus plinks Abfragen (Ctrl-C wirkt dort nicht, M0 B4).
- **Eingaben an plink blockieren nie:** Master nicht blockierend, Rest in einem Puffer bis 4 MiB, Nachlieferung über eine Schreibquelle.
- Telnet und Raw sind in der Schnellverbindung schon wählbar (Plan: M5); geprüft ist bisher nur Raw (Tests).

## Wichtige Erkenntnisse

Siehe `docs/M0-Machbarkeit.md` (B1–B18), `docs/M1-Recherche.md` (PuTTY-Fakten) und `docs/M1-Pruefliste.md`.
