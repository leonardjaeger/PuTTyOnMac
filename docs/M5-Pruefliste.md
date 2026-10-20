# M5 – Prüfliste: Tunnel, Proxy, Jump-Host, Telnet/Raw/Seriell

**Stand:** 20.10.2026 · Version 0.1.1 (Build 2) · noch nicht committet (erst nach Abnahme, Tag `m5`)
**Messungen:** `docs/M5-Machbarkeit.md` · **Tests:** 174 Kern (22 Suiten, Swift Testing) + 87 App (11 Klassen, XCTest), alle grün, ohne Compiler-Warnungen (Aufträge `m5k5`, `m5t4`)

## Was neu ist

- **Tunnel im Editor** (Abschnitt „Tunnel“, nur SSH): Liste der Weiterleitungen (Lokal, Entfernt, Dynamisch) mit Entfernen,
  darunter Art, Port, Ziel, Zielport und „Hinzufügen“. Format wie PuTTY (`PortForwardings`), vorhandene Einträge bleiben
  unverändert, derselbe lokale Port zweimal wird abgelehnt. Schalter „Lokale Ports auch für andere Rechner im Netz öffnen“
  (`LocalPortAcceptAll`) mit orangem Hinweis.
- **Belegter lokaler Port:** Vor dem Start prüft die App (::1 und 127.0.0.1); belegt → Hinweis im Terminal und im Inspektor
  (plink selbst schweigt dazu ohne `-v`).
- **Proxy im Editor:** Kein Proxy, SOCKS 4/5, HTTP (Server, Port, Benutzer), SSH-Jump-Host (Auswahl aus den gespeicherten
  SSH-Sitzungen), Lokaler Befehl (Feld + orange Warnung mit dem Befehl so, wie plink ihn ausführt; Rückfrage vor jedem
  Verbinden wie bisher). Schalter „Auch Ziele auf diesem Mac über den Proxy“ (`ProxyLocalhost`). Proxy-Schleifen und
  beschädigte Werte: kein Verbinden.
- **Seriell:** Verbindungsart „Seriell“ im Editor (nicht in der Schnellverbindung): Gerät aus `/dev/cu.*` mit „Geräte neu
  suchen“, Geschwindigkeit, Datenbits, Stoppbits, Parität, Flusskontrolle (nur was plink unter macOS umsetzt). Seitenleiste
  zeigt das Gerät, Inspektor „Gerät, Baud“, Status sofort „Verbunden“. Ohne Gerät: eigene Meldung.
- **PuTTY-Patch 0002** (deine Zustimmung, nur Seriell): Zeichen gehen sofort ans Gerät, kein lokales Echo, Ctrl-C und CR
  kommen an. SSH, Telnet, Raw unverändert.
- **Telnet** geprüft: nach der Verhandlung Zeichenmodus, Echo vom Server (App-Test). **Raw** bleibt im Zeilenmodus mit
  lokalem Echo (PuTTY-Standard), bewusst so.
- **Oberfläche (Plan 3.1):** Inspektor-Abschnitt „Tunnel“ (Art, Port → Ziel, Hinweis bei belegtem Port, „Hinzufügen …“ bzw.
  „Bearbeiten …“ öffnet den Editor beim Abschnitt „Tunnel“); Zeile „Über“ für Proxy/Jump-Host; Symbolleisten-Knopf „Tunnel“
  und Verbindung › „Tunnel bearbeiten …“ (nur bei gespeicherten SSH-Sitzungen aktiv).

## So prüfst du

Eine Testumgebung läuft noch: Testserver 127.0.0.1:2222 (nur Schlüssel), Testseite auf Port 28181, Ersatzgerät für Seriell,
Sitzungen „M5/Mac“, „M5/Tunnel“, „M5/Sprung“, „M5/Seriell“ in der Debug-App. Aufräumen nach der Abnahme: ich führe `ui stop` aus.

- [ ] „M5/Tunnel“ verbinden, im Terminal Return drücken („Press Return to begin session“), dann im Browser
      `http://127.0.0.1:28180` → „M5-TESTSEITE“
- [ ] Im Editor von „M5/Tunnel“ eine dynamische Weiterleitung 28182 hinzufügen, neu verbinden (⌘R), Return; im Browser
      (oder Firefox) SOCKS-Proxy 127.0.0.1:28182 einstellen → `http://127.0.0.1:28181` lädt
- [ ] „M5/Sprung“ verbinden: Terminal zeigt „Making proxy SSH connection …“ und „Making primary SSH connection …“, Inspektor
      „Über: SSH über „M5/Mac““
- [ ] „M5/Seriell“ verbinden und tippen: Das Ersatzgerät antwortet in Großbuchstaben, ohne doppeltes Echo
- [ ] Belegter Port: in Terminal.app `nc -l 28180` starten, „M5/Tunnel“ neu verbinden → Hinweis „Lokaler Port 28180 ist schon
      belegt …“ im Terminal und orange im Inspektor
- [ ] Heimserver im Heimnetz (Adresse aus dem Plan): lokale Weiterleitung auf seine Weboberfläche im Browser öffnen
- [ ] Optional Jump-Host Mac → Heimserver (braucht „Entfernte Anmeldung“ auf dem Mac)
- [ ] Editor: Proxy-Art wechseln (SOCKS → SSH-Jump-Host → SOCKS) – das Feld zeigt immer, was gespeichert ist
- [ ] In Xcode ⌘U: alle Tests grün
- Offen: serielles Gerät mit 115200 Baud (kein Adapter); Test von außen (nicht gewünscht)

## Entscheidungen für dich

1. **Weiterleitungen erst nach Return:** plink zeigt „Press Return to begin session“ auch nach Schlüssel-Anmeldung, und die
   Tunnel stehen erst danach (gemessen). Seit M1 bleibt die Echtheitsabfrage an. Vorschlag: so lassen, Hinweis steht in
   Inspektor und Editor. Alternative: `-no-antispoof` nur für Sitzungen ohne Passwort/Abfragen – schwächt den Schutz vor
   gefälschten Abfragen eines Servers.
2. **„Tabelle“ als Liste:** Vorhandene Weiterleitungen lassen sich entfernen und neu anlegen, nicht direkt bearbeiten
   (ponytail). Eine `Table` mit Spalten erst, wenn du sie willst.
3. **Fenster-Controller** (774 Zeilen, +40 in M5) nicht aufgeteilt; Vorschlag: in M6 Symbolleiste/Menüprüfung auslagern.
4. **PuTTY-Fehler melden:** Seriell im Zeilenmodus (Patch 0002), `\` am Ende von `PortForwardings`, ungesetzter Proxy-Wert,
   Proxy-Schleife ohne Meldung, `POLLHUP` (0001).

## Skill-Protokoll

| Skill | Wofür | Umgesetzt | Bewusst nicht |
|---|---|---|---|
| `anthropic-skills:ponytail` (von dir genannt) | ganzer Chat | Plattform zuerst: plink macht Tunnel/Proxy/Seriell, App schreibt nur die Sitzung; Liste statt Tabelle; Telnet-Proxy nur anzeigen; keine eigenen Seriell-Werte, die plink nicht umsetzt | Live-Status je Tunnel (plink meldet keinen), `-v`-Auswertung |
| `anthropic-skills:vibe-security` (von dir genannt) | Regeln vor dem Code, Audit am Ende | Prüfregeln für alle neuen Werte (S3/S4), Warnungen für offene Ports, Seriell-Pfade, Schleifen- und Beschädigungsschutz | Web-Abschnitte nicht zutreffend |
| `anthropic-skills:ponytail-review` | Prüfer-Agent | 10 Befunde, 9 umgesetzt (siehe unten) | „A“ als Adressfamilie beim Zurückschreiben (wirkungslos) |
| `apple-skills:macos` | AppKit/SwiftUI-Brücke, `sizingOptions`, Sheets | Abschnitte als SwiftUI im vorhandenen AppKit-Gerüst | `macos-tahoe-apis/` (RL 7.4 Regel 4) |
| `apple-skills:swift` | Swift 6, MainActor | Kern-Typen `Sendable`, App im MainActor-Standard | – |
| `apple-skills:testing` + `mattpocock-skills:tdd` | Tests zuerst | Kern-Tests vor dem Code (Seams laut Plan: SessionFile-Leser/Schreiber, Prüfregeln, ConnectionSummary); App-Tests Ende-zu-Ende mit echtem plink (PTY-Gerät, Telnet-Dienst, belegter Port) | Oberflächen-Tests für SwiftUI-Zustand (nur Klickprüfung) |
| `apple-skills:swiftui` + `anthropic-skills:swiftui-pro` | Editor-/Inspektor-Abschnitte, Review | Werte im `init` statt `onAppear` (sonst schriebe das Öffnen Vorgaben), eigene View-Dateien, Buttons mit Text + `.labelStyle(.iconOnly)`, VoiceOver-Label je Entfernen-Knopf, `ErrorText` geteilt | `PortForwarding: Identifiable` (Liste wird je Zeichnen neu gelesen) |
| `apple-skills:design` | Texte, SF Symbols, Systemfarben | Warnungen orange, Fehler rot, Symbol `point.3.connected.trianglepath.dotted` für „Tunnel“ | – |
| `anthropic-skills:computer-use` | Oberflächenprüfung | Klickprüfung aller neuen Abschnitte, Symbolleiste, Inspektor, Jump-Host und Seriell in der App | Tippen und Menüs: für Terminal-Apps nur Klick-Stufe |
| `mattpocock-skills:code-review` | Spec/Standards | 20 Spec-Punkte (15 erfüllt, 1 mit Hinweis, 4 teilweise → 2 behoben, 2 als Entscheidung oben), Standards: doppelter Speicherpfad, doppelte Fehlerzeile, doppelter Zustand behoben | Fenster-Controller aufteilen (Entscheidung 3) |

## Sicherheits-Audit (vibe-security, nur M5)

**Kritisch:** keiner. **Hoch:** keiner.

**Mittel (behoben)**
1. `SessionWarning.swift` – Zahl-Bindadresse (`D0.0.0.0:1080`) öffnete einen SOCKS-Proxy ins Netz ohne Warnung und war beim
   Import vorausgewählt. Vorher: Warnung nur bei `LocalPortAcceptAll`. Nachher: `listensBeyondLoopback` → Warnung
   `.openLocalPorts`, nicht vorausgewählt; Port-Prüfung überspringt solche Einträge.
2. `PortForwardings` mit `\` am Ende: plinks `gppmap` liest über das Ende hinaus. Vorher: Wert ging an plink. Nachher:
   `hasDanglingEscapeInPortForwardings` → „beschädigt“, kein Verbinden (auch in Proxy-Sitzungen).
3. `ProxyEditorSection.swift` – Feld zeigte einen anderen Proxy, als gespeichert war (zwei Zustände für `ProxyHost`, Jump-Host
   schrieb `ProxyMethod=6` ohne Sitzung → Sprung über „proxy“). Nachher: ein Zustand; „SSH-Jump-Host“ schaltet bis zur Wahl
   den Proxy aus; der Kern verwirft einen Sitzungsnamen als SOCKS/HTTP-Server.

**Niedrig (behoben)**
4. Proxy-Schleife (Sitzung nennt sich selbst): plink hing ohne Meldung → Fehler „verweisen im Kreis“, kein Verbinden.
5. Unbestimmter Proxy (`ProxyType` außerhalb 0–4 ohne gültiges `ProxyMethod`): plink liest einen ungesetzten Wert, die App
   hätte ein gespeichertes Passwort herausgegeben → kein Verbinden, kein Passwort.
6. Seriell: Import mit Pfad außerhalb `/dev` → Hinweis (nicht vorausgewählt); Editor nimmt nur `/dev/…` ohne „..“. Proxy-Befehl
   in seriellen Sitzungen zählt nicht mehr als Gefahr (plink öffnet keine Netzverbindung).
7. Doppelter Port beim Hinzufügen ersetzte still eine vorhandene Weiterleitung → abgelehnt.

**Geprüft, unauffällig:** S1 (kein Proxy-Passwort gespeichert, mit Proxy nie Schlüsselbund-Passwort), S3 (alle Werte über
die Sitzungsdatei, Ziele/Proxy-Server nach Server-Regeln, Jump-Host nach Sitzungsnamen-Regeln, Argumentliste unverändert),
S4 (alle Setter ohne CR/LF/NUL, Rückfrage beim lokalen Befehl auch über Jump-Sitzungen), S5 (Hostschlüssel des Jump-Hosts
fragt plink selbst), S8 (PortCheck bindet nur Loopback, schließt sofort; Kindprozess erbt nichts), S9/S11 (keine neuen
Protokollzeilen mit Werten; Texte über `SessionWarning.visible`), S14 (Tests und Doku nur Platzhalter, 127.0.0.1, `server.example`,
`/dev/cu.usbserial-1`). Nicht zutreffend: Datenbank, Zahlungen, Web-Header, KI-Schlüssel, Rate-Limits.

## Reviews

- **Prüfer-Agent** (ponytail-review + vibe-security, unabhängig): 1 „muss“ (Proxy-Zustand), 5 „sollte“ (zweites „=“, Bindadresse,
  doppelter Port, `ProxyType`, Jump-Schleifen), Tests, 3 „schön“ – alle umgesetzt bis auf „A“-Familie beim Schreiben.
  Seine Annahme „ProxyType ≥ 5 = SOCKS“ stimmt nicht (settings.c lässt den Wert ungesetzt) – umgesetzt als „nicht verbinden“.
- **Code-Review** (Spec/Standards): Proxy-Zustand, Tunnel-Abschnitt ohne Funktion bei Schnellverbindungen (jetzt
  ausgeblendet), Seriell ohne Gerät (eigene Meldung), Jump-Kandidaten nur SSH, `update` über `apply`, `ErrorText` geteilt,
  VoiceOver-Label, zweites Lesen der Sitzung beim Start – umgesetzt.
- **Eigene Oberflächenprüfung:** Schnellverbindung ohne Seriell; Tunnel-Knopf öffnet den Editor beim Abschnitt „Tunnel“;
  Entfernen schreibt nur `PortForwardings` (übrige Zeilen byte-gleich, geprüft); Seriell ohne „Benutzer“ und mit sofortigem
  „Verbunden“; Jump-Host-Verbindung in der App; Inspektor „Über“. Lokale Weiterleitung per curl erst nach Return erreichbar
  (Entscheidung 1).

## Betroffene Altbereiche

M1 (Prozessstart, Patch-Mechanik in `build-putty.sh`), M2 (Editor, Warnliste beim Import: neue Hinweise `openLocalPorts`,
`serialDevice`; Proxy-Anzeige ersetzt „Proxy ausschalten“; Proxy-Schleife jetzt Fehler statt still), M3 (kein Passwort mit
Proxy/unbestimmtem Proxy), M4 (Statuszeile bei Seriell).
