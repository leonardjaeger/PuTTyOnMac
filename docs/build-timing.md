# Build-Timing

Je Meilenstein einmal gemessen (Richtlinien 3.1 Regel 4). Mac mit Apple Silicon, Xcode über den Bauwächter, Debug.

## M1 (15.10.2026)

| Messung | Wert |
|---|---|
| Sauberer Bau (eigenes DerivedData, SwiftTerm aus vorhandenem Checkout, PuTTY aus dem Cache) | 15 s Wandzeit |
| davon `SwiftCompile` (32 Aufgaben, parallel, Summe) | 37,2 s |
| `SwiftEmitModule` / `SwiftDriver` | 3,1 s / 1,3 s |
| Asset-Katalog | 1,0 s |
| Phase „PuTTY-Werkzeuge bauen“ mit gültigem Stempel (nur kopieren und signieren) | 0,5 s |
| PuTTY-Neubau (neuer Stempel: Quelle, Patch oder Skript geändert) | ca. 12–15 s zusätzlich |
| Bau nach Änderung einer Datei (`ConnectionWindowController.swift`) | 7 s |
| Alle Tests (`go.sh test`: 39 Kern + 14 App, inkr. Bau) | ca. 7–16 s |

**Langsame Stellen:** keine. Mit `-warn-long-function-bodies=100` und `-warn-long-expression-type-checking=100` gab es keine Warnung. Der größte Posten ist SwiftTerm (fremder Code, unverändert).

Messskript: `build/m1/cmd.sh`-Fassung vom 15.10.2026 (im Log `m1s20` des Bauwächters).

## M6 (20.10.2026)

| Messung | Wert |
|---|---|
| Sauberer Bau in eigenem DerivedData (SwiftTerm aus dem Checkout, PuTTY aus dem Cache), mit `-warn-long-function-bodies=100` und `-warn-long-expression-type-checking=100` | 33 s Wandzeit, keine Warnung |
| Bau nach Änderung einer Datei (`FileTransferController.swift`) | 4 s |
| Kern-Tests (`go.sh kern`) / alle App-Tests | ≈ 20 s / ≈ 60 s Testlauf |

Messskript: `build/m6/timing.sh` (Auftrag `m6z1`).

## M7 (20.10.2026)

| Messung | Wert |
|---|---|
| Sauberer Bau in eigenem DerivedData (SwiftTerm aus dem Checkout, PuTTY aus dem Cache), mit `-warn-long-function-bodies=100` und `-warn-long-expression-type-checking=100` | 25 s Wandzeit, keine Warnung |
| Bau nach Änderung einer Datei (`ConnectionWindowController.swift`) | 3 s |
| Kern-Tests / alle App-Tests (`go.sh test`) | ≈ 0,2 s Testlauf (208 Tests) / ≈ 59 s Testlauf (113 Tests, davon `ThroughputTests` ≈ 30 s) |
| Weitergabe-DMG (`build.sh dmg`: Release-Bau, Prüfungen, DMG) | ≈ 1 min, DMG 5,3 MB, App 11 MB |
| Kurzanleitung laden (Hauptthread) | 2 ms als RTF (vorher 195–245 ms als HTML über WebKit) |
| Release-App: Start bis Prozess / Speicher / CPU im Leerlauf | 0,15 s / 52 MB Footprint / 0,1 % |

Messskript: `build/m7/timing.sh` (Auftrag `m7z1`), Messung der Release-App `build/m7/ui.sh messen` (Auftrag `m7m1`).

