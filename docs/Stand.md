# Projektstand SSH-App

**Stand:** 15.10.2026 · **Letzter abgenommener Meilenstein:** M0 (Tag `m0`, Commit `61e1442`) · **Nächster:** M1 Fundament

## Version und Bausteine

| Baustein | Stand |
|---|---|
| App | noch keine (M1 legt das Xcode-Projekt an) |
| PuTTY | 0.85 aus `Quellen/putty-0.85.tar.gz`, SHA-256 `13fd4db2936d03b73812a7bcc2a658e4dd29cc776a56c3670a7fc6f1a0ee8af8`, GPG „Release Key 2026“ (`1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5`) |
| SwiftTerm | 1.99.0 (Commit `2dad6a1e516f755bed77cf9bbd09455062f54758`), nur `TerminalView` |
| Sandbox | keine (Hardened Runtime) – Plan 8.7 |
| Tests | noch keine (ab M1) |

## Bauen

- **Bauwächter:** `SSH-App Bauwächter.command` im Terminal starten. Aufträge über `Scripts/go.sh <modus> <name>`; Modi `build`, `test`, `skript`, `log`. Auftragsnamen immer neu (`m1b1`, `m1t1` …).
- `skript` führt `build/skript.sh` aus – für M1 auf `build/m1/run.sh` umbiegen.
- Bauergebnisse und signierte Pakete **nur** unter `~/Library/Caches/SSH-App-Build/` (der Schreibtisch liegt in iCloud Drive; `codesign` bricht dort ab).
- Der Bauwächter führt aus, was in `build/skript.sh` bzw. den Meilenstein-Skripten steht. Fenster schließen, wenn er nicht gebraucht wird; Absicherung ist Aufgabe in M1.
- Auf dem Mac fehlt `gpg`; GPG-Prüfungen bisher in der Cloud.

## Wichtige Erkenntnisse aus M0

Siehe `docs/M0-Machbarkeit.md` (Befunde B1–B18) und die M1-Vorgaben im Plan: Startweg `posix_spawn`, Terminaltyp über die Sitzungsdatei, `-pwfile` nur für die erste verdeckte Abfrage, „Press Return to begin session“, kein Ctrl-C bei plinks lokalen Abfragen.
