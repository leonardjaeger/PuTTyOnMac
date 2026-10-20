# TunnelTerminal

Native Mac-App für PuTTY-Sitzungen. Die App nutzt PuTTYs eigenes `plink` als Verbindungsprogramm und zeigt das Terminal mit [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) an. Einen eigenen SSH-Code enthält sie nicht: Protokoll, Kryptografie und Prüfung der Hostschlüssel bleiben bei PuTTY.

**Stand:** Version 0.9.0 (Meilensteine M1–M7): Schnellverbindung `benutzer@server:port`, SSH/Telnet/Raw/Seriell, native Tabs, gespeicherte Sitzungen (Editor, Import aus PuTTY und Windows-`.reg`, Export), Schlüssel (Erzeugen und Umwandeln über puttygen), freiwilliges Passwort im Schlüsselbund, bekannte Hostschlüssel, Profile, Suchen, Port-Weiterleitungen, Proxy und Sprungserver, Dateiübertragung über pscp, `ssh://`- und `telnet://`-Links mit Bestätigung, Einstellungen, Kurzanleitung und Kürzel-Übersicht im Hilfe-Menü. Vor Version 1.0 folgt eine Sicherheitsprüfung.

## Voraussetzungen

- macOS 14 oder neuer, Apple Silicon
- Xcode 27 (damit gebaut und getestet), `cmake` (zum Bauen der PuTTY-Werkzeuge)
- PuTTY-Quellen 0.85 als `Quellen/putty-0.85.tar.gz` (offizieller Tarball; die Prüfsumme steht in `Scripts/build-putty.sh`)

## Bauen

`TunnelTerminal.xcodeproj` öffnen, beim SwiftTerm-Plugin einmal „Trust & Enable“ wählen, dann ⌘R. Die Phase „PuTTY-Werkzeuge bauen“ baut `plink`, `pscp`, `psftp` und `puttygen` aus dem geprüften Tarball und legt sie signiert nach `Contents/Helpers`.

Tests: ⌘U (Kern-Paket `TunnelTerminalCore` mit Swift Testing, App mit XCTest).

## Weitergabe

`bash Scripts/build.sh dmg` (über den Bauwächter) baut die Release-Fassung, prüft Signatur, Hardened Runtime, fehlende `get-task-allow`-Berechtigung (App und Hilfsprogramme) und dass keine Pfade mit Benutzernamen im Paket stehen, und legt `build/Weitergabe/TunnelTerminal-<Version>.dmg` mit „Zuerst lesen“ (Erstes Öffnen ohne Beglaubigung durch Apple) und SHA-256 daneben an. Die App ist ad hoc signiert, nicht notarisiert. Die Kurzanleitung im Hilfe-Menü entsteht aus `Scripts/hilfe/Kurzanleitung.html`: nach Änderungen `bash Scripts/kurzanleitung.sh` ausführen (der DMG-Bau bricht ab, wenn die RTF-Datei nicht zur Quelle passt).

## PuTTY-Updates

Die PuTTY-Werkzeuge sind fest eingebaut (Hilfe › PuTTY-Version zeigt die Version). Neue Versionen kündigt das PuTTY-Projekt auf seiner [Website](https://www.chiark.greenend.org.uk/~sgtatham/putty/) und im [Release-Feed](https://www.chiark.greenend.org.uk/~sgtatham/putty/releases.rss) an; die Mailingliste ist eingestellt. Bei einer Sicherheitsversion: neuen Tarball nach `Quellen/`, Version und SHA-256 in `Scripts/build-putty.sh` ändern, GPG-Signatur mit `--gpg-pruefen` prüfen, eigene Patches prüfen, neue App-Version weitergeben.

## Sicherheit

- plink wird nur mit `-load <Sitzung>` gestartet; Server, Benutzer und Werte stehen in einer Sitzungsdatei (`0600`) in einem eigenen PuTTY-Ordner. Eingaben mit führendem `-`, Leer- oder Steuerzeichen werden abgelehnt.
- Start über `posix_spawn` an einem eigenen Pseudo-Terminal; das Programm erbt nur Ein- und Ausgabe.
- Zwischenablage-Zugriffe (OSC 52) und Links aus der Server-Ausgabe nur nach Rückfrage (strenger einstellbar); Lesen der Zwischenablage ist verboten.
- `ssh://`- und `telnet://`-Links: nur Benutzer, Server und Port, immer mit Bestätigung; Links mit Passwort, Parametern oder Optionen werden abgelehnt.
- Hostschlüssel werden nie automatisch angenommen.
- Passwörter liegen nur im Schlüsselbund dieses Macs und gehen über eine Pipe an plink (`-pwfile /dev/fd/3`), nie als Argument oder Datei; sie gelten nur für Benutzer, Server und Port, für die sie gesichert wurden.
- PuTTY wird ohne GSSAPI gebaut: plink lädt keine fremden Bibliotheken.

## Lizenz

MIT, siehe [LICENSE](LICENSE). Fremdcode (PuTTY, SwiftTerm) und der eigene PuTTY-Patch: siehe [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
