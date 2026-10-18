# TunnelTerminal

Native Mac-App für PuTTY-Sitzungen. Die App nutzt PuTTYs eigenes `plink` als Verbindungsprogramm und zeigt das Terminal mit [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) an. Einen eigenen SSH-Code enthält sie nicht: Protokoll, Kryptografie und Prüfung der Hostschlüssel bleiben bei PuTTY.

**Stand:** Version 0.1.1 (Meilenstein M1 und Umbenennung U1) mit Schnellverbindung `benutzer@server:port`, SSH/Telnet/Raw und nativen Tabs. Gespeicherte Sitzungen, Schlüssel, Tunnel und Weitergabe folgen.

## Voraussetzungen

- macOS 14 oder neuer, Apple Silicon
- Xcode 27 (damit gebaut und getestet), `cmake` (zum Bauen der PuTTY-Werkzeuge)
- PuTTY-Quellen 0.85 als `Quellen/putty-0.85.tar.gz` (offizieller Tarball; die Prüfsumme steht in `Scripts/build-putty.sh`)

## Bauen

`TunnelTerminal.xcodeproj` öffnen, beim SwiftTerm-Plugin einmal „Trust & Enable“ wählen, dann ⌘R. Die Phase „PuTTY-Werkzeuge bauen“ baut `plink`, `pscp`, `psftp` und `puttygen` aus dem geprüften Tarball und legt sie signiert nach `Contents/Helpers`.

Tests: ⌘U (Kern-Paket `TunnelTerminalCore` mit Swift Testing, App mit XCTest).

## Sicherheit

- plink wird nur mit `-load <Sitzung>` gestartet; Server, Benutzer und Werte stehen in einer Sitzungsdatei (`0600`) in einem eigenen PuTTY-Ordner. Eingaben mit führendem `-`, Leer- oder Steuerzeichen werden abgelehnt.
- Start über `posix_spawn` an einem eigenen Pseudo-Terminal; das Programm erbt nur Ein- und Ausgabe.
- Zwischenablage-Zugriffe (OSC 52) und Links aus der Server-Ausgabe werden nicht ausgeführt.
- Hostschlüssel werden nie automatisch angenommen.

## Lizenz

MIT, siehe [LICENSE](LICENSE). Fremdcode (PuTTY, SwiftTerm) und der eigene PuTTY-Patch: siehe [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
