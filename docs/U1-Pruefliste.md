# U1 – Umbenennung zu TunnelTerminal und neues App-Icon: Prüfliste

**Stand:** 18.10.2026 · Version **0.1.1 (Build 2)** · Grundlage: Tag `m1` · **abgenommen am 18.10.2026** („passt“) · Commit „Umbenennung zu TunnelTerminal, neues App-Icon“, Tag `u1`

Der alte Arbeitstitel wird in dieser Datei bewusst nicht ausgeschrieben, weil der neue Grundsatz-Test ihn außerhalb von `docs/M0-*`/`docs/M1-*` verbietet.

## 1. Antworten auf die Eingangsfragen

| Frage | Antwort Leonard | Umgesetzt |
|---|---|---|
| Projektordner umbenennen? | Ja | `~/Desktop/CoWorkClaude/TunnelTerminal` |
| Projekt-Dokumente umbenennen? | Ja | `claude/TunnelTerminal_Entwicklungsplan.md`, `claude/TunnelTerminal_Prompts.md` (alte entfernt, Querverweise angepasst; Kopien im Projektordner) |
| GitHub-Repo umbenennen? | Ja, in `TunnelTerminal` (macht Leonard) | Remote-URL wird angepasst, sobald das Repo umbenannt ist |

## 2. Umsetzung

| Nr. | Punkt | Status | Nachweis |
|---|---|---|---|
| 1 | Bauwächter angehalten, alle Vorkommen des alten Namens im Repo umgestellt (Code, `project.pbxproj`, Scheme, `Config/Info.plist`, `Scripts/`, Bauwächter, README, `docs/`, `.gitignore`, auch `build/m0`- und `build/m1`-Skripte); Verlauf in `docs/M0-*`/`docs/M1-*` unverändert | ✅ | 126 Dateien im Diff; Grundsatz-Test grün |
| 2 | Umbenennung von Target, Product Name, Bundle Display Name, Modul, Schemes, Quellordnern und `@testable import` | ✅ | `git mv` für alle Ordner/Dateien (Verlauf bleibt); `project.pbxproj` Feld für Feld umgestellt und jede geänderte Zeile im Diff geprüft (Objekt-IDs unverändert, so wie Xcodes Umbenennen es macht); `plutil -lint` ok; `xcodebuild -list`: Targets `TunnelTerminal`, `TunnelTerminalTests`, Schemes `TunnelTerminal`, `TunnelTerminalCore`; Bau ohne Warnungen |
| 2a | Kennungen | ✅ | Bundle-ID `de.leonardjaeger.tunnelterminal`, Tests `de.leonardjaeger.tunnelterminal.tests`, Log-Subsystem und `OSLogPreferences`-Schlüssel gleich; Präfix `TunnelTerminal-Schnell-` (jetzt aus `AppIdentity.name` abgeleitet); Cache `~/Library/Caches/TunnelTerminal-Build/`; `TunnelTerminal Bauwächter.command` |
| 3 | Daten übernommen | ✅ | `Application Support/<alter Arbeitstitel>/putty` → `Application Support/TunnelTerminal/putty` verschoben (`sshhostkeys`, `randomseed`, leeres `sessions/`); Rechte vorher und nachher 0700/0600 (Auftrag `u1s1`). Nichts gelöscht: der jetzt leere alte Ordner bleibt stehen. **Schlüsselbund:** 165 Einträge geprüft (nur Dienst/Bezeichnung gelesen), **keiner** mit alter oder neuer Kennung (Auftrag `u1s2`) |
| 4 | Neuer Grundsatz-Test `noOldWorkingTitle` | ✅ | Prüft alle Repo-Dateien laut `git ls-files` (eingecheckt und neu, ohne Ignoriertes) samt Dateinamen; Muster trifft den alten Namen mit Bindestrich, Unterstrich, Leerzeichen oder zusammengeschrieben. Erst rot (87 Dateien), fand im ersten Lauf auch einen eigenen Kommentar, jetzt grün |
| 5 | `Design/Logo-Final/` ins Repo, ohne `_alt-TunnelSSH/` | ✅ | `.gitignore`: `Design/*`, `!Design/Logo-Final/`, `Design/Logo-Final/_alt-TunnelSSH/`, `__pycache__/` (59 Dateien). Name in Logo-Leitfaden, `web/site.webmanifest`, Präsentation (Text, eingebettete Bilder, `lang='de'`, Notizfolie) und Skripten umgestellt; die fünf Folien-PNGs aus der geänderten HTML neu gerendert; Fenstertitel im Dock-Mockup ersetzt (gleiche Schrift und Farbe, Kalibrierung pixelgenau). S14-Prüfung siehe Abschnitt 6 |
| 5a | App-Icon | ✅ | `AppIcon.appiconset` aus `Design/Logo-Final` byte-gleich übernommen; 16 px, 32 px (16@2x, 32@1x) = Kleinfassung; die zehn alten Platzhalter-PNGs entfernt; `AppIcon.icns` im Paket |
| 6 | Bau, Tests, eigene Oberflächenprüfung | ✅/⏳ | Bau ok (`u1b1`, `u1b2`), **40 Kern-Tests + 14 App-Tests grün** (`u1t5`). Selbst geprüft: Menüleiste „TunnelTerminal“ (Menüs TunnelTerminal, Ablage, Bearbeiten, Darstellung, Verbindung, Fenster, Hilfe), Fenster „Neue Verbindung“, Icon im Finder groß und in der 16-px-Spalte scharf. **Dock, ⌘-Tab und die localhost-Verbindung prüft Leonard** (Dock/⌘-Tab erscheinen nicht in meinen Bildschirmfotos, in Terminal-Apps darf ich nicht tippen) |
| 7 | Plan, `docs/Stand.md`, README, `docs/CONTEXT.md`, Version 0.1.1 (Build 2) | ✅ | Plan Version 8: Name, Entscheidung 3 erledigt, Abschnitt U1, M7 ohne Umbenennung, Markenprüfung offen; Prompts: Pfade, M7 ohne Namensfrage. Die „Umgesetzt“-Notiz im Plan folgt nach der Abnahme |

## 3. So prüfst du

- [ ] **Dock:** Tunnel-Icon, beim Drüberfahren „TunnelTerminal“. Zeigt es noch das alte Icon: im Terminal `killall Dock` (leert den Icon-Zwischenspeicher)
- [ ] **⌘-Tab:** Icon scharf
- [ ] **Finder** (Liste/Spalte, 16 px): Icon scharf – von mir schon gesehen
- [ ] **Schnellverbindung** `localhost` → **keine** neue Hostschlüssel-Abfrage (die bekannten Schlüssel sind umgezogen), danach Passwort bzw. „Press Return“
- [ ] **Xcode:** `TunnelTerminal.xcodeproj` öffnen → ⌘U alle Tests grün, keine Warnungen im Issue-Navigator (Xcode verlangt vorher „Install Required“ für Systemkomponenten – das braucht dein Passwort, ich habe es nicht ausgelöst)
- [ ] GitHub-Repo in `TunnelTerminal` umbenennen (Settings), dann sage ich die Remote-URL um

## 4. Messwerte

| Messung | Ergebnis |
|---|---|
| Debug-Bau in leerem Cache (inkl. PuTTY-Werkzeuge) | ok, ohne Warnungen (nur die bekannte AppIntents-Notiz) |
| Tests | Kern 40 (Swift Testing, 5 Suiten), App 14 (XCTest), alle grün |
| Release-Bau (`u1r3`/`u1r6`, eigener Cache `ReleaseCheck`) | ok; Bundle-ID, 0.1.1 (2); App und plink/pscp/psftp/puttygen mit `flags=0x10002(adhoc,runtime)` = Hardened Runtime; `codesign --verify --deep --strict` ok. Der allererste Release-Lauf in leerem Cache endete mit „BUILD FAILED“; die Ausgabe war gefiltert, der Grund ist daher nicht bekannt. Der unveränderte zweite und dritte Lauf waren grün |
| Alter Name im Release-Paket | 0 Treffer |
| `/Users/` im Release-Paket | 1 Datei (`Contents/MacOS/TunnelTerminal`): Verweise auf DerivedData-Objektdateien mit Benutzername (Debug-Zuordnung), vorbestehend, nicht durch U1 entstanden – siehe offene Punkte |

## 5. Offene Punkte

1. **Markenprüfung „TunnelTerminal“** steht aus (Kurzsuche am 18.10.2026 fand keine gleichnamige App). Vor der Weitergabe erledigen.
2. **GitHub:** Repo-Umbenennung (Leonard) und danach Remote-URL anpassen.
3. **Vor der Weitergabe (M7/Härtung):** Release-Binary ohne `/Users/…`-Verweise bauen (Symbole entfernen bzw. Archiv-Weg mit `STRIP_INSTALLED_PRODUCT`/`DEPLOYMENT_POSTPROCESSING`) und `com.apple.security.get-task-allow` aus der Release-Signatur nehmen (sonst scheitert die Notarisierung). Beides gab es schon vor U1.
4. **Leerer alter Ordner** `~/Library/Application Support/<alter Arbeitstitel>` – soll ich ihn löschen? (Nur nach deiner Zustimmung.)
5. Künftige Umbenennungen würden wieder einen Datenumzug brauchen, weil der PuTTY-Ordner aus dem App-Namen gebildet wird (Hinweis aus dem Review; bewusst so gelassen, der Auftrag verlangt `TunnelTerminal/putty`).

## 6. Sicherheits-Audit (vibe-security, Prüfer-Agent)

**Kritisch:** keine · **Hoch:** keine

**Mittel – behoben:** `.gitignore` schloss Plan und Arbeitsanweisungen nur unter den neuen Dateinamen aus; eine liegengebliebene Kopie unter altem Namen (mit den Heimserver-Adressen) wäre bei `git add -A` mitgegangen (S12, S14).
- Vorher: `TunnelTerminal_Entwicklungsplan.md` / `TunnelTerminal_Prompts.md`
- Nachher: `*_Entwicklungsplan.md` / `*_Prompts.md`

**Niedrig – behoben:** Python-Bytecode aus `build_icons.py`/`wordmark.py` enthält absolute Pfade mit Benutzernamen (S14).
- Nachher: `__pycache__/` in `.gitignore`

**Ohne Befund:** S9 (Masken unverändert, Subsystem = Bundle-ID = `OSLogPreferences`-Schlüssel), S1/S5 (Hostschlüssel ziehen mit um, Schlüsselbund nur Attribute gelesen), S3/S4/S8 (Logik unverändert, Sitzungsname beginnt nie mit `-`), S12 (keine Zugangsdaten), S14 im Design-Ordner (keine IP-, E-Mail-Adressen, `/Users/`-Pfade oder Namen; nur Platzhalter wie `server.example`; 13 eingebettete Bilder in der Präsentation sind reine Logo-SVGs). **Content Credentials (C2PA)** in allen SVG und PNG dekodiert: nur Anthropic-Signatur, Standardtext, Zufalls-IDs, Hashes – keine persönlichen Daten. Hinweis: In den geänderten SVG/HTML-Dateien und im neu beschrifteten Mockup passt bzw. fehlt die Content-Credential-Signatur nun (nur Titel/Text geändert).

**Nicht zutreffend:** Datenbank-Regeln (Supabase, Firebase, Convex), Server-Authentifizierung/JWT, Rate-Limits, Zahlungen (Stripe), Mobile-Bundles, KI-Schlüssel, HTTP-Header, CORS, Deployment – die App hat keinen Server und kein Konto.

## 7. Reviews

**ponytail-review (Prüfer-Agent):** Umbenennung vollständig und stimmig, kein Codeüberschuss. Umgesetzt: die zwei `.gitignore`-Zeilen, `Scripts/watch.sh` wieder ausführbar (hatte beim Bearbeiten das Ausführrecht verloren), Grundsatz-Test robuster (fehlertolerantes Dekodieren, Muster mit `_`/Leerzeichen), Mockup-Titel und Notizfolie, `wordmark.py` Standardwert `Terminal` (vorher Rest der verworfenen Variante), Leitfaden nennt Python 3.12+. Nicht umgesetzt: Abbruch des Umzugsskripts bei laufender alter App (Einmal-Lauf ist erledigt, das Skript bleibt lokal).

**code-review, Achse Standards:** Harte Befunde behoben (`.gitignore`-Ausnahme `!build/u1/pruef.sh`, Ausführrecht `watch.sh`, `docs/Stand.md`). Ermessensfragen: Präfix aus `AppIdentity.name` abgeleitet (umgesetzt); gemeinsame `Scripts/env.sh` für den Cache-Pfad, Subsystem aus `Bundle.main`, Aufräumen der Design-Skripte, Inter-Hinweis in `THIRD_PARTY_NOTICES.md` (Schrift nur als Umrisse im Logo) – bewusst nicht, weil nicht verlangt (ponytail).

**code-review, Achse Spec:** Fehlende Prüfliste (diese Datei) und `Stand.md` nachgezogen; Notizfolie der Präsentation aktualisiert; `build/skript.sh` zeigt jetzt auf das eingecheckte `build/u1/pruef.sh`; `wordmark.py` korrigiert. Hinweis: Der Ausschluss `Design/*` hält auch die Vorrunde `Design/Logo-Runde-1/` aus dem Repo (gefordert war nur „Logo-Final ohne `_alt-TunnelSSH`“). Alte Schnellsitzungen mit altem Präfix gibt es nicht (`sessions/` war beim Umzug leer).

**release-review:** Bundle-ID, Version, Icon, Signatur und Hardened Runtime nach der Umbenennung in Ordnung; zwei Weitergabe-Punkte (`/Users/`-Verweise, `get-task-allow`) für M7 notiert.

## 8. Skill-Protokoll

| Skill | Wofür | Umgesetzt | Bewusst nicht |
|---|---|---|---|
| `anthropic-skills:ponytail` | ganzer Auftrag | kleinste Änderung: Pfade per `git mv`, Inhalte per fester Zuordnung, Präfix aus einer Quelle; keine Zusatzfunktionen | Datenumzug nicht als App-Code (einmaliger Umzug auf einem Mac, als lokales Skript) |
| `anthropic-skills:vibe-security` | S1–S14 vor dem Umzugsskript, Audit am Ende | Schlüsselbund nur Attribute, `mv` statt Kopieren/Löschen, S14-Prüfung Design, Audit (Abschnitt 6) | Web-Abschnitte nicht zutreffend |
| `anthropic-skills:ponytail-review` | Abschluss-Review durch Prüfer-Agenten | Befunde 1–7 (Abschnitt 7) | Befund 8 (Umzugsskript) |
| `apple-skills:macos` | Projektaufbau, Signatur ohne Sandbox | Struktur App/Kern/Tests unverändert | `macos-tahoe-apis/` nicht genutzt (Richtlinien 7.4) |
| `apple-skills:swift` | Swift 6 im neuen Test | `Process`/`Pipe` synchron im Test, keine neue Nebenläufigkeit | – |
| `apple-skills:testing` + `mattpocock-skills:tdd` | Grundsatz-Test | erst rot (87 Treffer), dann Umbenennung, dann grün; Fitness-Function-Muster wie die übrigen Grundsatz-Tests | keine weiteren Tests (Umbenennung ändert kein Verhalten) |
| `apple-skills:design` | Icon in Dock, Finder, Menüleiste | Icon-Set übernommen, Kleinfassung 16/32 px geprüft (Finder), Menüleiste geprüft | Icon-Composer-Datei (`.icon`) nicht verlangt; Ebenen liegen in `Design/Logo-Final/IconComposer-Ebenen` |
| `apple-skills:release-review` | Signatur, Bundle-ID, Hardened Runtime | Release-Bau geprüft (Abschnitt 4) | Notarisierung erst M7 |
| `mattpocock-skills:code-review` | Abgleich mit Auftrag (Spec) und Richtlinien (Standards) seit `m1` | zwei Achsen getrennt durch Unter-Agenten (Abschnitt 7) | – |
| `anthropic-skills:computer-use` | eigene Oberflächenprüfung | Finder, Menüleiste, Fenster | Dock/⌘-Tab nicht sichtbar, Tippen in Terminal-Apps nicht erlaubt → Leonard |

## 9. Abweichungen vom Auftrag

- Prüfung in Xcode selbst steht aus (Komponenten-Installation nötig); geprüft über `xcodebuild` (Bau ohne Warnungen, `-list`, `plutil -lint`).
- `build/u1/cmd.sh` (Datenumzug) bleibt lokal, weil es den alten Namen enthalten muss; eingecheckt ist `build/u1/pruef.sh` (Release-Prüfung). Sein Inhalt steht in den Bauwächter-Logs `u1s1`/`u1s2`.
- Zusätzlich zur Spec: Folien-PNGs neu gerendert, Mockup-Titel ersetzt, `__pycache__/` ignoriert (Review-Befunde).
