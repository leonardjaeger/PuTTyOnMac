# M6 – Machbarkeit: Dateiübertragung mit pscp

**Stand:** 20.10.2026 · Messskript `build/m6/machbarkeit.sh` mit `build/m6/probe.py` (im Repo, Aufzeichnungen nur lokal im
Cache), pscp 0.85 aus `Scripts/build-putty.sh`, Wegwerf-sshd aus M1 auf 127.0.0.1:2222 (nur Schlüssel, eigener Agent; für
M6 um `Subsystem sftp` ergänzt). pscp läuft wie in der App an einem eigenen PTY ohne Steuerterminal (`setsid`, umask 077).
Benutzername im Log maskiert (S14).

## 1. Was pscp tut (gemessen)

| Test | Ergebnis |
|---|---|
| Hochladen `pscp -load s -sftp -batch /abs/datei 127.0.0.1:ordner` | klappt; Anmeldung samt Übertragung kleiner Dateien ≈ 0,06–0,08 s (lokal) |
| Fortschritt | auf stdout, etwa einmal je Sekunde neu mit `\r`: `name(25 Zeichen) | 101544 kB | 101544.0 kB/s | ETA: 00:00:03 |  24%`, am Ende `100%` + `\r\n`; auch ohne `isatty`. 400 MB lokal in 1,7 s |
| Abbrechen mit `SIGHUP` beim Hochladen | pscp endet sofort (Signal); **auf dem Server bleibt die angefangene Datei** (391 von 400 MB) |
| Abbrechen beim Herunterladen | auf dem Mac bleibt die angefangene Datei (278 MB) → die App lädt in eine versteckte Teildatei im Zielordner und benennt erst nach Erfolg um |
| Vorhandene Datei beim Hochladen | **wird ohne Frage überschrieben** (SFTP `OPEN` mit `TRUNC`) → die App listet den Zielordner vorher (`-ls`) und fragt |
| `-ls ordner` | „Listing directory …“, dann `ls -l`-Zeilen vom Server (mit `.` und `..`); Steuerzeichen in Namen entfernt pscp (`with_stripctrl`), Umlaute bleiben (E2E-Test „Grüße.txt“); ein Mac als Server unterscheidet Groß-/Kleinschreibung nicht → die App vergleicht ohne; Ordner fehlt: „Unable to open …: no such file or directory“, Exit 1 |
| Zielordner gibt es nicht, eine Datei | pscp legt eine **Datei mit dem Ordnernamen** an → die App prüft den Ordner vorher mit `-ls` |
| Leerer Pfad (`server:`) | persönlicher Ordner |
| `~/ordner` | **wird nicht erweitert** (sftp-server, „no such file or directory“) → die App entfernt ein „~/“ vorn |
| Herunterladen in eine eigene Datei | Name auf dem Mac bestimmt allein die App; Rechte **vom Server** ohne die umask 077 (aus 0755 wird 0700, also ausführbar; Prüfer-Agent, pscp.c) → die App setzt vor dem Umbenennen 0600 |
| Joker im Pfad (`a*b?[c].txt`) | pscp sucht selbst nach passenden Dateien (SFTP); maskiert (`a\*b\?\[c\].txt`) lädt es genau diese Datei |
| Datei fehlt / Pfad ist ein Ordner | „unable to identify …: no such file or directory“ / „…: is a directory“, Exit 1 |
| Zielordner ohne Schreibrecht | „unable to open …: permission denied“, Exit 1 |
| Name mit `\` auf dem Mac (`a\b.txt`) | landet als **`b.txt`** auf dem Server (pscp schneidet nach dem letzten `\` ab) → die App lehnt solche Namen ab |
| **`--`** | **pscp 0.85 überspringt das Argument nach `--`** (`arglistpos` wird doppelt erhöht, pscp.c) → nicht verwenden; Dateien gehen als absolute Pfade (beginnen nie mit „-“) |
| Hostschlüssel unbekannt, `-batch` | zeigt den Fingerabdruck, „Connection abandoned.“, „FATAL ERROR: Cannot confirm a host key in batch mode“ – nimmt nie an (S5) |
| Benutzer leer | pscp **nimmt still den Benutzer dieses Macs** („Guessing user name“, nur mit `-v` sichtbar) → die App fragt nach dem Benutzer |
| Passwort nötig (System-sshd, Tastatur-interaktiv), `-batch` | „FATAL ERROR: Cannot answer interactive prompts in batch mode“ → die App fragt nach dem Passwort und gibt es über `-pwfile /dev/fd/3` (wie plink) |
| Jump-Host-Sitzung (`ProxyMethod=6`) | klappt („Making proxy SSH connection …“) |

## 2. Server im Aufruf

Mit `-load` ersetzt pscp den Server der Sitzung durch den Server aus „server:pfad“ (`do_cmd`: „Patch in hostname“).
Anders als bei plink (S3) muss der Server deshalb ins Ziel. Er wird wie in der Schnellverbindung geprüft (kein „-“ vorn,
kein „@“, kein einzelnes „:“), IPv6 in eckige Klammern (pscp trennt am ersten „:“ außerhalb davon). Ein Server mit
nur einem Zeichen geht nicht: „x:pfad“ hält pscp für einen Pfad mit Laufwerksbuchstaben (`colon()`) → die App lehnt ihn ab. Benutzer und alle
übrigen Werte bleiben in der Sitzungsdatei: Die App schreibt für jede Übertragung eine vorübergehende Kopie der Sitzung
mit eingetragenem Benutzer (Präfix der Schnellsitzungen, wird nach dem Lauf und beim Start/Ende der App entfernt).

## 3. Folgen für die Umsetzung

- Immer `-sftp` (SCP schickt den Zielpfad durch die Shell des Servers) und `-batch`; kein `--`.
- Hochladen: erst `-ls` des Zielordners (prüft, dass es ihn gibt, und liefert die Namen für die Überschreiben-Frage), dann je
  Datei ein Lauf (Fortschritt und Abbruch je Datei eindeutig; eine Anmeldung kostet lokal ≈ 0,06 s).
- Herunterladen: nur genau eine Datei (Joker maskiert) in eine versteckte Teildatei im gewählten Ordner; nach Erfolg
  umbenennen (ersetzt erst dann eine vorhandene Datei), sonst löschen.
- Nicht gemessen: IPv6-Server (der Wegwerf-sshd lauscht nur auf 127.0.0.1), ein echtes Passwort über `-pwfile` mit pscp
  (dieselbe Funktion wie bei plink, M0 B5) – bei der Abnahme prüfen.
