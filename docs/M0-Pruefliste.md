# M0 – Prüfliste

**Stand:** 15.10.2026 · **Meilenstein:** M0 Machbarkeitstest · **Ergebnisdatei:** `docs/M0-Machbarkeit.md` · **Status:** abgenommen am 15.10.2026 (Commit, Tag `m0`, Plan nachgeführt)

---

## 1. Umfang laut Plan (Abschnitt 5, M0) und Prompt M0

| # | Punkt | Stand | Nachweis |
|---|---|---|---|
| 1 | Eigener Bauwächter `SSH-App Bauwächter.command` mit Modi `build`, `test`, `skript`, `log` | ✅ | `Scripts/watch.sh`, `Scripts/build.sh`, `Scripts/go.sh`; 30+ Aufträge (`m0u1` … `m0h1`) ohne Ausfall |
| 2 | Tarball prüfen: SHA-256 gegen offizielle Liste | ✅ | fester Wert und `sha256sums` stimmen überein (B10) |
| 3 | Tarball prüfen: GPG-Signatur | ✅ | `VALIDSIG 1A07DAC0…E5B5` (Release Key 2026) für Tarball und `sha256sums`; geprüft in der Cloud, weil auf dem Mac `gpg` fehlt |
| 4 | PuTTY ohne GTK bauen, `plink -V`, `otool -L` (nur `libSystem`), Vergleich mit `Quellen/Vergleich-Builds/plink` | ✅ | M11: 12 s, nur `libSystem`, 0 Treffer `/Users/`, Version und Größe identisch mit dem Vergleichs-Build (nur kopiert, nicht eingebaut) |
| 5 | Wegwerf-Prototyp mit SwiftTerm, startet `plink -ssh <NSUserName()>@localhost`, `TERM=xterm-256color` | ✅ mit Abweichungen | Swift-Paket statt `.xcodeproj` (dokumentiert); zwei Startwege A (`LocalProcessTerminalView`) und B (`posix_spawn`); Benutzername nur zur Laufzeit. `TERM` erst nach Abhilfe für PuTTY-Fehler B11 korrekt |
| 6 | Hostschlüssel-Abfrage, Passwort | ✅ | M1 |
| 7 | `top`, `vim`, `htop` | ✅ / ⚠️ | `top` und `vim` ok; **`htop` nicht gemessen** – auf dem Mac nicht installiert (geprüft) |
| 8 | Fenstergröße ändern | ✅ | M2 (A und B, B per eigenem `SIGWINCH`) |
| 9 | Umlaute, 256 Farben | ✅ | M1 (`äöüß ÄÖÜ €`, `tput colors` = 256, Farbtabelle, Truecolor) |
| 10 | Sandbox-Variante: `network.client`, plink mit `app-sandbox` + `inherit` | ✅ gemessen | braucht zusätzlich `network.server` (B15); Terminal-Steuerung gesperrt (B14) |
| 11 | Sandbox: Schlüsseldatei über Öffnen-Dialog | ✅ | M6: Datei lesbar (B6 widerlegt); mit Wegwerf-Schlüssel, `~/.ssh` unverändert |
| 12 | Sandbox: `/dev/cu.*` | ✅ | M8 |
| 13 | Passwort Schlüsselbund → Pipe → `-pwfile /dev/fd/3`, nicht in `ps` | ✅ | M3/M4/M5, mit und ohne Sandbox |
| 14 | `docs/M0-Machbarkeit.md` mit Messwerten und Sandbox-Empfehlung ja/nein mit Grund | ✅ | Empfehlung: **nein (vorerst)**, Abschnitt 3 |
| 15 | Plan 8.7 erst nach Leonards Zustimmung ändern | ✅ | Zustimmung am 15.10.2026, danach nachgeführt |
| 16 | vibe-security-Audit, ponytail-review durch Prüfer-Agent, code-review | ✅ | Abschnitte 3 und 4 |
| 17 | Commit, Tag, Plan-Nachführung erst nach Abnahme | ✅ | nach der Abnahme vom 15.10.2026 |

## 2. Wichtigste Ergebnisse (Kurzfassung)

1. **Variante A (plink + SwiftTerm) ist machbar.** Ohne Sandbox funktionieren Anmeldung, Schlüsselbund-Passwort über `-pwfile`, Vollbild-Programme, Fenstergröße, Umlaute und Farben.
2. **Startweg B (`posix_spawn`) statt `LocalProcessTerminalView`.** Weg A vererbt Deskriptoren der App (darunter zwei beschreibbare) und gibt die Zwischenablage per OSC 52 an den Server heraus – beides gemessen.
3. **Sandbox: nein (vorerst).** Die Sandbox verbietet plink, sein Terminal umzuschalten. Ohne aufwendige Umwege sind Eingaben doppelt, Vollbild-Programme kaputt und getippte Passwörter sichtbar.
4. **Zwei PuTTY-Eigenheiten** für M1: `$TERM` wird nicht übernommen (Fehler in 0.85, Abhilfe über Sitzungsdatei); `-pwfile` gilt nur für die erste verdeckte Abfrage (2FA scheitert).
5. **Bauen außerhalb von iCloud:** Der Schreibtisch liegt in iCloud Drive, signierte Pakete dort scheitern.

---

## 3. Sicherheits-Audit (vibe-security)

Geprüft: `build/m0/Prototyp/Sources/Prototyp/main.swift`, Entitlements, `build/m0/*.sh`, `Scripts/*.sh`, Ablauf der Messungen. Schwerpunkt laut Prompt: Pipe-Übergabe und Prozessstart.

**Nicht zutreffend** (keine solche Technik im Projekt): Datenbank-Zugriffsschutz (Supabase/Firebase/Convex), Web-Authentifizierung/JWT, Rate-Limiting, Zahlungen, Mobile, KI-Schnittstellen, Web-Deployment/Header, SQL.

**Geheimnisse:** Keine Schlüssel, Tokens oder Passwörter im Code oder in Skripten. Das Testpasswort lag nur im Schlüsselbund (Eintrag „SSH-App-M0-Test“) und ist gelöscht (geprüft). Der Wegwerf-Schlüssel ist gelöscht.

### Kritisch
Keine Befunde im Code.

### Hoch

**H1 · Sandbox: plink kann die Anzeige der Eingabe nicht abschalten – Passwort sichtbar** (Prototyp-Sandbox-App, Weg A und B; B14)
Gemessen am 15.10.: In der Sandbox-App wurde das an plinks Abfrage getippte Mac-Passwort im Klartext angezeigt. Wer auf den Bildschirm schaut, eine Bildschirmaufnahme macht oder den Terminal-Verlauf kopiert, hat das Passwort.
```text
Vorher:  App Sandbox + plink mit inherit → tcsetattr auf /dev/ttys* verweigert → ECHO bleibt an
Nachher: M1 ohne App Sandbox (Hardened Runtime). Falls die Sandbox später nötig wird: Terminal-Modi
         vollständig in der App verwalten (über den Master) – nicht auf plink verlassen
```

**H2 · Weg A (`LocalProcessTerminalView`) gibt Deskriptoren und Zwischenablage preis** (`main.swift`, `ForkptySession`; B2, B3)
plink erbte fd 3–6 der App, darunter zwei **beschreibbar** geöffnete Cachedateien. Ein manipulierter Server bzw. eine präparierte Datei, die man per `cat` anzeigt, bekam per OSC 52 den Inhalt der Zwischenablage (gemessen mit Testtext) und konnte sie ohne Rückfrage überschreiben.
```swift
// Vorher (Weg A)
let term = LocalProcessTerminalView(frame: …)
term.startProcess(executable: plink, args: args, environment: env)   // forkpty: erbt alle fds, OSC 52 offen

// Nachher (Weg B, in M1 übernehmen)
let term = TerminalView(frame: …)            // eigener Start:
// posix_spawn mit POSIX_SPAWN_CLOEXEC_DEFAULT, adddup2(slave → 0/1/2), adddup2(pipe → 3)
func clipboardRead(source: TerminalView) -> Data? { nil }            // OSC 52 abgelehnt (S11)
func clipboardCopy(source: TerminalView, content: Data) { }           // abgelehnt
```

**H3 · Bauwächter führt aus, was im iCloud-Ordner steht** (`Scripts/watch.sh` → `build.sh` Modus `skript` → `build/m0/cmd.sh`; Prüfbericht M3)
Jedes Gerät oder Programm, das in `~/Desktop/CoWorkClaude/SSH-App` schreiben kann (iCloud-Synchronisation!), kann einen Auftrag und ein `cmd.sh` ablegen und damit Befehle mit den Rechten des Terminals ausführen, solange der Bauwächter läuft.
```bash
# Vorher
bash build/skript.sh          # führt beliebigen Inhalt aus, Ablage im iCloud-Schreibtisch

# Nachher (M1)
REQ="$HOME/Library/Caches/SSH-App-Build/requests"     # Ablage außerhalb von iCloud
shasum -a 256 build/skript.sh build/m1/*.sh >> "$log" # Inhalt/Prüfsumme protokollieren
timeout 1800 bash build/skript.sh                     # Zeitlimit je Auftrag
```
Sofortmaßnahme: Das Bauwächter-Fenster schließen, wenn er nicht gebraucht wird.

### Mittel

**M1 · Passwortkopien bleiben im Speicher** (`main.swift`, `secretPipe` und `loadTestPassword`)
`[UInt8](secret)` wird durch `append(0x0a)` neu angelegt; der alte Puffer mit dem Passwort wird ungelöscht freigegeben, `memset_s` trifft nur die neue Kopie. Die `Data` aus dem Schlüsselbund wird nie gelöscht. Folge: Das Passwort kann in Speicherabbildern (Absturzbericht, Auslagerung) stehen.
```swift
// Vorher
var bytes = [UInt8](secret); bytes.append(0x0a)
write(fd, bytes, bytes.count); memset_s(&bytes, …)

// Nachher (M1): ohne Zwischenkopie, danach Quelle löschen
var data = secret
data.withUnsafeBytes { p in
    var iov = [iovec(iov_base: UnsafeMutableRawPointer(mutating: p.baseAddress), iov_len: p.count),
               iovec(iov_base: UnsafeMutableRawPointer(mutating: newline), iov_len: 1)]
    _ = writev(fd, &iov, 2)
}
data.resetBytes(in: 0..<data.count)
```

**M2 · `-pwfile` bricht bei einer zweiten verdeckten Abfrage ab** (B12; PuTTY `cmdline.c`)
2FA-Server, die nach dem Passwort ein zweites Feld schicken, scheitern mit „Configured password was not accepted“. Kein Sicherheitsleck, aber Nutzer könnten zur unsicheren Umgehung greifen. M1: nach genau dieser Meldung „ohne gespeichertes Passwort erneut verbinden“ anbieten.

**M3 · GPG-Prüfung akzeptiert jeden importierten Schlüssel** (`build/m0/02-tarball.sh:35`)
`grep -q VALIDSIG` prüft nicht den Fingerabdruck. Abgemildert durch den festen SHA-256-Wert.
```bash
# Vorher
echo "$out" | grep -q 'VALIDSIG' || fail=1
# Nachher (Scripts/build-putty.sh, M1)
echo "$out" | grep -q 'VALIDSIG 1A07DAC0F220CF12248EA7195C67D0F88BC3E5B5' || fail=1
```

**M4 · Noch keine `.gitignore`; Logs enthalten lokale Pfade mit Benutzernamen** (S14)
`build/m0/out.txt` und `build/logs/*.log` enthalten u. a. `ps`-Zeilen und `lsof`-Pfade mit dem Benutzernamen. Vor `git init`:
```gitignore
build/
Quellen/
SSH-App_Entwicklungsplan.md
```

### Niedrig

- **N1 · Dateirechte im `PUTTYDIR`:** `sshhostkeys` und `Default%20Settings` entstanden mit `0644` (Ordner `0700`, daher nicht lesbar für andere Benutzer). M1: Dateien mit `0600` schreiben.
- **N2 · Deskriptor-Wiederverwendung nach Fensterschließen** (`windowWillClose` → Cancel schließt den Master, `master` behält die Nummer): `master = -1` im Cancel-Handler setzen.
- **N3 · Statusdatei nicht atomar** (`Scripts/watch.sh`): in Temp-Datei schreiben, dann `mv`.
- **N4 · Ctrl-C bei plinks lokalen Abfragen wirkungslos** (kein Steuerterminal in Weg B): eigene „Abbrechen“-Schaltfläche in M1.

### Ablauf-Vorfall (kein Code-Befund)
Beim Sandbox-Test M6 wurde ein an plinks Abfrage getipptes Passwort wegen H1 sichtbar angezeigt. Es wurde nirgends gespeichert; das Fenster wurde sofort geschlossen.

### Zusammenfassung Audit
1. **H1 Sandbox + plink (Hoch):** Passwort kann sichtbar werden → keine Sandbox in M1.
2. **H2 Weg A (Hoch):** Deskriptor-Lecks und Zwischenablage → Weg B.
3. **H3 Bauwächter (Hoch):** nur laufen lassen, wenn gebraucht; in M1 Ablage aus iCloud nehmen.
4. **M1–M4 (Mittel):** Passwortkopien, 2FA mit `-pwfile`, GPG-Fingerabdruck, `.gitignore` – alles als Vorgaben für M1.

---

## 4. Prüfbericht (ponytail-review + code-review durch Prüfer-Agent)

Ein Prüfer-Agent, der den Code nicht geschrieben hat, hat `ponytail-review` und `mattpocock-skills:code-review` geladen und Code, Skripte und Doku gegen die PuTTY- und SwiftTerm-Quellen geprüft. Kritisch: keine.

| Befund | Schwere | Behandlung |
|---|---|---|
| B12 war zu optimistisch (nur erste Abfrage, 2FA bricht ab) | Hoch (Doku) | **korrigiert** in `M0-Machbarkeit.md`; Audit M2 |
| Sandbox-Messungen „ohne Gegenmaßnahme“ stammten aus einem früheren Bau – nicht ersichtlich | Mittel (Messung) | **korrigiert**: M1-Zeile nennt jetzt je Ergebnis Bau und Weg |
| Passwortkopie im Speicher | Mittel | Audit M1, Vorgabe für M1 |
| Bauwächter führt fremde Befehle aus | Mittel | Audit H3 (hochgestuft wegen iCloud) |
| Kommentar `TIOCSWINSZ` „auf beiden Seiten“ veraltet | Niedrig | **korrigiert** im Prototyp |
| B4-Begründung „XNU“ unbelegt; Ctrl-C ohne Steuerterminal | Niedrig | **korrigiert** (Begründung `O_NOCTTY`/`adddup2`), Vorgabe M1 |
| `master` nach Schließen, `read` bei `EINTR`, Statusdatei nicht atomar, GPG-Fingerabdruck | Niedrig | Vorgaben für M1 (`M0-Machbarkeit.md` Abschnitt 4) |
| B17: `-no-antispoof` als Option nennen | Niedrig | **ergänzt** |
| S14 in Code und Doku eingehalten; Logs unter `build/` enthalten Benutzernamen | – | Audit M4 |

Vom Prüfer bestätigt: B1, B2, B3, B5, B11, B15, B17, die Ursache „Server-Zeilen ohne CR“ und die Gültigkeit der M6-Messung (B6 widerlegt). Unbelegt, nur gemessen: B13. Spec-Lücken: `htop` (nicht installiert), Prüfliste (jetzt vorhanden).

Ein früherer Prüfer-Agent (vor den Mac-Messungen, mit `ponytail-review` und `vibe-security`) hatte fünf Fehler im Prototyp gefunden; alle wurden vor den Messungen behoben (MainActor beim Start, `pipefail` im Paketierskript, fd-/PID-Wiederverwendung, Aufräumen in Fehlerpfaden, fehlendes `SIGWINCH`).

---

## 5. Skill-Protokoll

| Skill | Geladen? | Wofür | Umgesetzt | Bewusst nicht / Abweichung |
|---|---|---|---|---|
| `anthropic-skills:vibe-security` | ja – im Hauptchat erst **zum Audit**; der frühere Prüfer-Agent hatte ihn vor den Messungen geladen | Audit Abschnitt 3; S1/S11/S14 | Audit, Vorgaben für M1 | **Verstoß:** sollte zu Beginn geladen werden, vor dem Code mit Pipe und Prozessstart. Die Regeln S1–S14 aus dem Plan waren beim Schreiben aber berücksichtigt (Pipe statt `-pw`, Argumentliste statt Shell, Benutzername nur zur Laufzeit) |
| `anthropic-skills:ponytail` | ja – **erst am Ende** | Schlankheit | Prototyp ist bewusst klein (ein File, zwei Wege nur zum Messen); Shortcut „Swift 5“ markiert | **Verstoß:** sollte den ganzen Chat aktiv sein |
| `anthropic-skills:ponytail-review` | ja (Prüfer-Agenten) | Abschluss-Review | alle Befunde behandelt (Abschnitt 4) | – |
| `mattpocock-skills:code-review` | ja (Prüfer-Agent) | Spec/Standards | Spec-Lücken `htop` und Prüfliste behandelt | – |
| `apple-skills:macos` (`macos-capabilities/sandboxing.md`) | ja – erst am Ende, zum Gegenprüfen | Sandbox | Diagnose über `log show … deny` entspricht dem Modul | Das Modul sagt nichts zu Hilfsprogrammen mit `inherit` oder PTYs – die Empfehlung beruht allein auf Messungen und Quellcode |
| `mattpocock-skills:prototype` | **nein** | Wegwerf-Prototyp | – | **Versäumt.** Der Prototyp folgt trotzdem dem Wegwerf-Prinzip (Kennzeichnung im Kopf, nicht ins App-Projekt) |
| `mattpocock-skills:research` | **nein** | API-Fakten | Recherche lief über einen Subagenten nach `docs/M0-Recherche.md` und direkt im PuTTY-/SwiftTerm-Quellcode | **Versäumt** |
| `apple-skills:swift` | **nein** | Nebenläufigkeit, MainActor | – | **Versäumt**; MainActor-Fehler fand der Prüfer-Agent |
| `anthropic-skills:computer-use` | **nein** | Oberflächenprüfung | Computer-Steuerung im Hintergrund genutzt | **Versäumt** |
| `apple-skills:testing`, `mattpocock-skills:tdd` | nein | Tests | – | Für einen Wegwerf-Prototyp ohne übernommenen Code nicht angewendet; ab M1 Pflicht |

Lehre für M1: Pflicht-Skills **zu Beginn** laden und hier sofort eintragen.

---

## 6. Entscheidungen (Abnahme am 15.10.2026)

1. **M0 abgenommen.** `.gitignore`, `git init`, Commit, Tag `m0`.
2. **Sandbox (Plan 8.7):** „nein (vorerst)“ – Leonard hat zugestimmt.
3. **Planänderungen aus `M0-Machbarkeit.md` Abschnitt 4** werden in den Plan übernommen.
4. **Aufgeräumt:** siehe `M0-Machbarkeit.md` Abschnitt 5. Übrig ist nur die geschützte Verwaltungsdatei des Sandbox-Containers (32 KB, nur über den Finder löschbar).
5. Offen für Leonard: „Entfernte Anmeldung“ ausschalten, Bauwächter-Fenster schließen, wenn nicht gebraucht; optional Fehlerbericht an PuTTY zu B11.
