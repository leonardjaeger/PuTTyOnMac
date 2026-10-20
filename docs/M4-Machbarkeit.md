# M4: Machbarkeit und Messungen

Stand 19.10.2026 · Skripte `build/m4/machbarkeit.sh`, `build/m4/tempo.sh` (+ `tempo.py`), `build/m4/bench.sh` (+ `bench/`),
Bauwächter-Aufträge `m4s1`, `m4s4`–`m4s8`, App-Test `ThroughputTests`.

## 1. Sitzungsprotokoll über plink geht nicht

Wegwerf-sshd auf 127.0.0.1:2222 (nur Schlüssel), plink 0.85 aus dem App-Bau:

| Versuch | Ergebnis |
|---|---|
| `plink -sessionlog <datei>` (setzt `LogType` = 2, „alle Ausgaben“) | **keine Datei** |
| Sitzung mit `LogType=1` („druckbare Ausgabe“) | **keine Datei** |
| Sitzung mit `LogType=3` (SSH-Pakete) | Datei mit 37 KB, Rechte 0644 – Pakete enthalten auch Getipptes |

Grund im Quellcode: `logtraffic()` wird nur in `terminal/terminal.c` aufgerufen; plink hat keine Terminalemulation.
**Entschieden am 19.10.2026 (Leonard):** Die App schreibt die Ausgabe selbst mit (`SessionLogWriter`), Schalter je
Sitzung über `LogType` (1/2 = an, 0 = aus), Datei 0600 in `~/Library/Logs/TunnelTerminal` (Ordner 0700), nie Eingaben.
`LogType` 3/4 (Paketprotokoll von plink) zeigt der Editor als Warnung; der Schalter ersetzt es durch 2 bzw. 0.

## 2. Raw und Telnet: plink schaltet das Terminal nicht roh (für M5)

`unix/plink.c` ruft `ldisc_create()` vor `seat_echoedit_update(plink_seat, 1, 1)` auf. Die Leitungsdisziplin meldet
ihren Modus also, bevor plink das Terminal auf „Echo + Zeilenpuffer“ setzt; bei SSH korrigiert das der Server-Kanal
später, bei Raw nie. Folge: Bei Raw (und vermutlich Telnet) puffert das PTY Eingaben zeilenweise, unabhängig von
`LocalEcho`/`LocalEdit` (0 = an, 1 = aus, 2 = automatisch, putty.h). Für die App-Tests misst `TerminalComfortTests`
das Einfügen deshalb am Terminal statt am Socket. In M5 bei Telnet/Raw prüfen.

## 3. Tempo bei viel Ausgabe

| Messung | Ergebnis |
|---|---|
| plink allein, SSH `seq 1 1000000` an ein PTY (tempo.sh ssh) | 7,9 MB in 4,4 s, **3,5 MB/s** |
| plink allein, Raw 13,9 MB an ein PTY (tempo.sh raw) | **2,8 MB/s** |
| SwiftTerm-Parser ohne Ansicht, Debug (bench.sh) | **1,4 MB/s** |
| SwiftTerm-Parser ohne Ansicht, Release | **237 MB/s** |
| App-Weg im Debug-Test (`cat` → PTY → `TerminalProcess` → SwiftTerm), vorher | 0,3 MB/s |
| derselbe Weg nach Änderung (Lesen bis 8 ms je Ereignis) | **0,8 MB/s**, mit Protokoll ebenso; längste Pause der Hauptschleife 24–26 ms |

Folgerungen: Im Release-Bau begrenzt plink (≈ 3 MB/s), nicht die App. Debug-Zahlen taugen nur zum Vergleich.
`TerminalProcess` las vorher nur einen Block je Leseereignis; ein PTY liefert wenige KB je Lesen, dazwischen lief jedes
Mal die Hauptschleife samt Zeichnen. Jetzt liest es, solange Daten da sind, höchstens 8 ms je Ereignis (Tastatur und
Zeichnen bleiben flüssig). Das Sitzungsprotokoll schreibt im Hintergrund und kostet messbar nichts.
