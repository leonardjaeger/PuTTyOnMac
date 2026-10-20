# M7 – Prüfliste: Feinschliff & Weitergabe

**Stand:** 21.10.2026 · Version 0.9.0 (Build 3) · abgenommen am 21.10.2026 („Alles andere passt“), Tag `m7`
**Tests:** 208 Kern (27 Suiten, Swift Testing) + 113 App (XCTest), alle grün, ohne Compiler-Warnungen (Aufträge `m7k4`,
`m7t10`). Übersprungen werden nur die Bilder der Menü-Fenster (`SnapshotTests`, laufen eigens über `ui snap`, grün) und der
pscp-Ende-zu-Ende-Test aus M6 (braucht den Testserver).
**Weitergabe:** `build/Weitergabe/TunnelTerminal-0.9.0.dmg` (5,3 MB), SHA-256
`7d1139c138295ad52181a0e8a7ab59f4e72e2b00781e1486ad95534ab8067f14` (Auftrag `m7d3`).
**Messungen:** `docs/build-timing.md` (M7) · **Recherche:** `docs/M7-Recherche.md`

## Was neu ist

- **Einstellungen in vier Reitern:** Allgemein, Profile, **Sicherheit**, **Erweitert**.
  - *Sicherheit:* Wünsche des Servers – Zwischenablage füllen (OSC 52) „Jedes Mal fragen“ / „Immer ablehnen“, Links aus
    dem Terminal „Jedes Mal fragen“ / „Nie öffnen“; Links aus anderen Apps „Nach Bestätigung öffnen“ / „Nie öffnen“;
    dazu eine Übersicht, was immer gilt (mehrzeiliges Einfügen mit Rückfrage, Hostschlüssel nie ohne Bestätigung,
    Passwörter nur im Schlüsselbund).
  - *Erweitert:* welche App `ssh://` und `telnet://` öffnet, Knopf „TunnelTerminal als Standard festlegen“ (macOS fragt
    selbst nach), eingebaute PuTTY-Version mit Update-Hinweis und Knopf „PuTTY-Website öffnen“, Ordner für Sitzungen/
    Hostschlüssel und Sitzungsprotokolle im Finder zeigen.
- **Links `ssh://` und `telnet://` aus anderen Apps** (S6): Die App öffnet sie nur nach einer Rückfrage. Oben steht der
  **Server**, dann Port, Benutzer und Verbindungsart, darunter der ganze Link. „Abbrechen“ ist der Standardknopf.
  Bei Telnet steht „unverschlüsselt“ dabei, bei SSH der Hinweis auf die Schlüssel im Agenten. Übernommen werden nur Benutzer,
  Server und Port. Abgelehnt mit Begründung werden Links mit:
  - Passwort, auch kodiert als `%3A` – das Passwort erscheint dann auch in der Meldung nicht,
  - Parametern (`;fingerprint=…`, auch `%3B`), Pfad, Abfrage oder Anker,
  - einem kodierten `@` oder `/` im Benutzer (`%40`, `%2F`), denn damit ließe sich ein anderer Server vorspiegeln,
  - einem führenden „-“ (Optionen), Steuer- oder Leerzeichen, roh oder kodiert, sowie mit über 2048 Bytes.

  Ein freier Tab verbindet selbst, sonst öffnet sich ein neuer. Läuft die App ohne Fenster, öffnet sich eines. Kommen mehrere
  Links auf einmal, zählt nur der erste; solange eine Rückfrage offen ist, werden weitere verworfen.
- **Hilfe-Menü:** Kurzanleitung (eigenes Fenster, 10 Abschnitte), Tastenkürzel (liest die Menüleiste beim Öffnen, auch
  Einträge, die macOS selbst einsetzt, z. B. ⌃⇥; dazu die Tasten ohne Menüeintrag), PuTTY-Version (S7, mit Update-Hinweis
  und Knopf zur Website).
- **Über TunnelTerminal:** Autor nur dein Name; darunter die Lizenztexte aus dem App-Paket (`LICENSE`,
  `THIRD_PARTY_NOTICES.md`: PuTTY, SwiftTerm).
- **Menüleiste vollständig:** Darstellung › „Symbolleiste ein-/ausblenden“ (⌥⌘T) und „Symbolleiste anpassen …“; die
  Symbolleiste ist anpassbar und merkt sich die Anordnung. Jeder Symbolleisten-Knopf hat einen Menübefehl mit derselben
  Regel (getestet).
- **Optischer Feinschliff nach Entwurf B:** Seitenleiste mit der Verbindungsart rechts in jeder Zeile und 240 pt
  Mindestbreite. Statuszeile links Verbindung und Verbindungsart, rechts Größe, Zeichensatz und Protokoll. Der Hinweis beim
  mehrzeiligen Einfügen hat ein orangefarbenes Warnsymbol und einen getönten Hintergrund, der Text ist kürzer und bricht um.
  Akzentfarbe dunkler, damit weiße Schrift lesbar ist (Entscheidung unten).
- **Lokales Netzwerk (macOS 15):** `NSLocalNetworkUsageDescription` in der Info.plist. Beim ersten Verbinden zu einer Adresse
  im Heimnetz fragt macOS; Kurzanleitung und „Zuerst lesen“ erklären das.
- **Weitergabe-DMG** (`bash Scripts/build.sh dmg` über den Bauwächter):
  - Release-Bau ohne `get-task-allow` (Hinweis aus U1), ohne Debug-Symbole und ohne Pfade mit Benutzernamen.
  - Prüfungen vor der DMG: Signatur, Hardened Runtime, `get-task-allow` in App **und** Hilfsprogrammen, keine `/Users/`-Pfade
    und kein Benutzername außerhalb der Bundle-ID, Kurzanleitung passt zur Quelle.
  - DMG mit „Zuerst lesen“ (Installieren, Prüfsumme, erstes Öffnen unter macOS 15 und 14, Meldung „beschädigt“, lokales
    Netzwerk, Lizenz) und Verweis auf „Programme“. Danach Prüfung der DMG und SHA-256 daneben. Jeder Schritt bricht bei
    Fehlern ab.
- **Aufgeräumt:** Die Menü- und Symbolleistenregeln stehen in `TabCommandState`, ohne Fenster prüfbar. Die Rückfragen bei
  Wünschen des Servers stehen in `ServerRequestPrompts`, die Link-Rückfrage in `AppLinkPrompt`, die Textvorschau in
  `AlertText`. `private` ist nicht aufgeweicht. Der Fenster-Controller hat 684 statt 727 Zeilen, trotz der neuen Befehle.

## So prüfst du

Die Testumgebung läuft: Testserver 127.0.0.1:2222 (nur Schlüssel), Sitzungen „M7/Mac“ und „M7/Telnet“ (nur Platzhalter)
in der Debug-App, neu gestartet mit dem letzten Build. Deine Standard-Apps habe ich nicht geändert (`ssh://` öffnet weiter
Termius). Links gibst du deshalb direkt an die Debug-App, im Terminal:
`open -a ~/Library/Caches/TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app '<Link>'`
Nach der Abnahme räume ich mit `ui stop` auf: Testsitzungen, Testserver und nur die eigene Hostschlüssel-Zeile für
127.0.0.1:2222.

- [ ] **Einstellungen (⌘,):** vier Reiter. „Erweitert“ zeigt `ssh://` → Termius, `telnet://` → Terminal, „PuTTY 0.85“,
      Knopf „PuTTY-Website öffnen“ öffnet die Seite im Browser; unten „Änderungen gelten sofort.“
- [ ] **Link** `ssh://test@server.example:2222` → Rückfrage „Verbindung aus einem Link öffnen?“, erste Zeile
      „Server: server.example“, Verbindungsart mit Agent-Hinweis, Return = „Abbrechen“ (verbindet nicht)
- [ ] **Link** `telnet://192.0.2.10` → „Telnet – unverschlüsselt …“, „Port: 23 (Standard)“ → Abbrechen
- [ ] **Abgelehnt, ohne zu verbinden:**
  - [ ] `ssh://-oProxyCommand=x@server.example` → „Benutzername darf nicht mit „-“ beginnen.“
  - [ ] `ssh://test:geheim@server.example` → Passwort-Meldung, „geheim“ steht **nicht** im Dialog
  - [ ] `ssh://root%40prod.bank.example%2Flogin@server.example` → „Benutzername enthält unzulässige Zeichen.“
- [ ] **Ohne Fenster:** alle Fenster schließen (die App läuft weiter), dann einen Link → ein neues Fenster mit der Rückfrage
- [ ] **Einstellungen › Sicherheit**, „Links aus anderen Apps: Nie öffnen“ → Link → nur die Meldung; danach zurückstellen
- [ ] **Hilfe › Kurzanleitung** öffnet sofort; einfache Aufzählungszeichen, Hell und Dunkel lesbar
- [ ] **Hilfe › Tastenkürzel:** Gruppen wie die Menüleiste; unter „Fenster“ steht beim Wechsel zum nächsten Tab „⌃⇥“
      (vorher ein leeres Zeichen)
- [ ] **Hilfe › PuTTY-Version** → „PuTTY 0.85“ mit Update-Hinweis und Knopf zur Website
- [ ] **TunnelTerminal › Über TunnelTerminal:** nur dein Name als Autor, darunter MIT-Lizenz, PuTTY- und SwiftTerm-Lizenz
- [ ] **Darstellung:** ⌥⌘T blendet die Symbolleiste aus und ein; „Symbolleiste anpassen …“ öffnet die Anpassung
- [ ] **Hell/Dunkel:** Seitenleiste (Verbindungsart rechts), Statuszeile, Einfüge-Hinweis (in „M7/Mac“ drei Zeilen
      einfügen), Standardknöpfe in der Akzentfarbe mit weißer Schrift
- [ ] **VoiceOver (⌘F5):** Symbolleiste, Seitenleiste, Einstellungen und die Link-Rückfrage vorlesen lassen
- [ ] **DMG:** `build/Weitergabe/TunnelTerminal-0.9.0.dmg` öffnen, „Zuerst lesen“ lesen; `shasum -a 256` stimmt mit oben
      überein; App nach „Programme“ ziehen und starten (Rechtsklick › Öffnen bzw. Systemeinstellungen › „Dennoch öffnen“)
- [ ] Optional, **nach dem Installieren aus der DMG:** Einstellungen › Erweitert › „Als Standard festlegen“, dann in Safari
      `ssh://test@server.example` aufrufen. Das ändert deine Standard-App für `ssh://` (vorher Termius); zurück geht es in
      Termius oder über den gleichen Knopf dort.
- [ ] Optional: Heimserver im Heimnetz verbinden – beim ersten Mal sollte macOS nach dem lokalen Netzwerk fragen
- [ ] In Xcode ⌘U: alle Tests grün

Bilder der Menü-Fenster in Hell und Dunkel liegen in `~/Library/Caches/TunnelTerminal-Build/m7-snap/`.

## Code-Review (Standards und Spec, zwei getrennte Prüfer)

**Standards – behoben:**
- Fußnote „Änderungen gelten sofort.“ fehlte unter „Erweitert“ (Projektregel Einstellungen).
- Beispiele: „host“ → `server.example`, `fe80::1%25en0` → `2001:db8::1%25en0` (S14, nur Dokumentationsadressen).
- `AboutPanel.licenseTexts` und `ShortcutOverview.groupWithoutMenu` sind jetzt `private` (RL 3.2 Nr. 4).
- Lizenztext mit `split` statt `components(separatedBy:)` (RL 3.2 Nr. 8).
- `SnapshotTests`: `sizingOptions = []` (RL 3.4 Regel 19).
- *Ermessen, umgesetzt:*
  - Die Symbolleiste nutzt die Selektoren der Menübefehle, eine Regel statt zwei (`allows(toolbarItem:)` entfernt).
  - Link-Rückfrage als eigener Typ `AppLinkPrompt`, Vorschau neutral in `AlertText`. Abschalt-Einstellungen überall über
    injizierte `defaults`, ohne den Umweg über einen Fehler.
  - `SessionLibrary`: ein Wert je Sitzung statt zweier paralleler Wörterbücher; `kind` heißt jetzt `protocolTitle`.
  - Update-Text einmal (`PuTTYInfo.updateNote`), Schemata aus der Info.plist, `CFBundleURLName` über
    `$(PRODUCT_BUNDLE_IDENTIFIER)`.
  - Kurzanleitung: Der HTML-Import brauchte 195–245 ms auf dem Hauptthread (RL 3.7). Die App lädt jetzt eine daraus
    erzeugte RTF-Datei in 2 ms (`Scripts/kurzanleitung.sh`; der DMG-Bau prüft, dass sie zur HTML-Quelle passt).

**Standards – bewusst nicht geändert:**
- `'/Us''ers/'` in `make-dmg.sh`: Die Zeile sucht selbst nach diesem Muster. Zusammengesetzt findet der Grundsatztest sie
  nicht; eine Ausnahmeliste im Test wäre mehr Code für eine Zeile. Im Skript begründet.
- Die Tasten ohne Menüeintrag (Einfüge-Hinweis, F1–F4) stehen als feste Liste in der Übersicht, lesen lässt sich das nicht.
  Der Fußtext sagt das jetzt so.
- `showPuTTYVersion` fällt auf ein eigenes Fenster (`runModal`) zurück, wenn das Schlüsselfenster schon ein Sheet hat.

**Spec – behoben bzw. erledigt:**
- *VoiceOver:* Die Durchsicht ist belegt. Alle 17 Knöpfe des Hauptfensters sind beschriftet, gelesen aus dem
  Bedienungshilfen-Baum per Computer-Use. Neue Fenster haben eigene Beschriftungen. Neu: Ein Fehler beim Festlegen der
  Standard-App wird angesagt.
- *Fenster-Controller:* Die Menüprüfung ist herausgelöst, ebenso die Link-Rückfrage (684 statt 727 Zeilen).
- *Markenprüfung:* siehe „Für dich zu entscheiden“.
- *get-task-allow:* wird jetzt auch an den Hilfsprogrammen geprüft.
- *Links:* `%3A`/`%3B` (und nach dem Prüfer auch `%40`/`%2F`) werden nach dem Dekodieren geprüft.
- *Nicht verlangt (Scope):* steht unten zur Entscheidung.

## ponytail-review (Prüfer-Agent, unabhängig)

1. *Muss:* **Link ohne offenes Fenster ging verloren** → **behoben**, die App öffnet ein Fenster (per Computer-Use geprüft:
   alle Fenster zu, Link → neues Fenster mit Rückfrage).
2. *Muss:* **Prozentkodierung täuschte die Adresse** (`root%40bank.example%2F…@angreifer`) → **behoben**: erst dekodieren,
   dann prüfen; `@` und `/` im Benutzer abgelehnt; „Server:“ steht jetzt oben. Kerntest rot (`m7k3`) → grün (`m7k4`).
3. *Sollte:* Der Robustheitstest prüfte nur auf Absturz → **behoben**. Für angenommene Links gilt jetzt: kein `:;@/` im
   Benutzer, genau ein `@` in der Anzeige, nie ein führendes „-“; dazu kodierte Bausteine im Zufallsalphabet. Die Wahl des
   Fensters prüft ein Klick-Test von Hand, weil der `AppDelegate` im Testprogramm deinen echten PuTTY-Ordner liest.
4. *Sollte:* Kürzel-Übersicht zeigte von macOS eingesetzte Einträge falsch → **behoben**: ⇥, ⇤, Pfeile, F1–F35, ⌦, ⇞/⇟,
   „fn“ (wenn AppKit es meldet), Großbuchstabe = ⇧. Getestet mit einem eigenen Menü.
5. *Sollte:* Dunkler Akzent als Linkfarbe nur etwa 3,2:1 → Link durch einen Knopf ersetzt; die Farbe selbst entscheidest du.
6. *Sollte:* `get-task-allow` nur an der App geprüft → **behoben**.
7. *Sollte:* Fehler im DMG-Skript gingen verloren → **behoben** (jeder Schritt einzeln, ohne `pipefail`).
8. *Sollte:* Abgelehnter Link zeigte das Passwort → **behoben**, auch kodiert; getestet.
9. *Wäre schön:* Vor dem Start gewann der letzte Link → **behoben** (der erste zählt).
10. *Wäre schön:* Kein Klartext-Hinweis bei Telnet → **behoben**.
11. *Wäre schön:* VoiceOver erfuhr nichts vom Fehler unter „Erweitert“ → **behoben** (Ansage).
12. *Lean:* doppelter Port-Leser → **behoben**, `ConnectionLink` nutzt `Endpoint.port` (−7 Zeilen).
13. *Wäre schön:* `ui.sh stop` ließ den Test-Hostschlüssel zurück → **behoben** (nur die eigene Zeile).

*Vom Prüfer nicht geprüft, von mir nachgezogen:*
- Wird ein Tab mit offener Link-Rückfrage geschlossen, blieb die Sperre bisher stehen. Jetzt sperrt nur ein noch offenes
  Fenster mit Sheet.
- `commandState` baut bei jeder Menüprüfung ein paar Wahrheitswerte und die Auswahl neu – vernachlässigbar.
- `HelperProcess` war nicht Teil von M7 (geprüft in M3).

## Sicherheits-Audit (vibe-security)

Geprüft: der ganze M7-Diff mit dem Link-Weg als Eingabe von außen (Deep-Link-Regeln des Skills: jeden Teil prüfen, nichts
Geheimes übernehmen, nichts ohne Bestätigung). Außerdem die Release-Konfiguration und das DMG-Skript. Zusätzlich hat der
Prüfer-Agent ein eigenes Audit gemacht.

**Nicht zutreffend** (native App ohne Backend): Datenbank-Zugriff/RLS, Web-Anmeldung (JWT, Middleware, Server Actions,
API-Routen), Rate-Limits, Zahlungen, Mobil-Bundles, KI/LLM, Web-Deployment (Header, CORS, Source Maps), SQL/ORM,
`NEXT_PUBLIC_`/`VITE_`-Variablen.
**Geheimnisse:** keine im Diff (gesucht nach Schlüsselmustern, `-pw`, IP-Adressen außer Dokumentationsadressen, E-Mails,
`/Users/`). Ein Mastodon-Konto in der Recherche habe ich entfernt (S14).

### Kritisch
Keine.

### Hoch (behoben)

**Release-Bau – `get-task-allow` in der Signatur (Hinweis aus U1, S8)**
Mit dieser Berechtigung kann sich ein Prozess desselben Benutzers als Debugger an die App und an plink hängen und das
Passwort aus dem Speicher lesen, das plink über die Pipe bekommt.
```
// Vorher (Release)
CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES (Standard)
// Nachher
CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO; make-dmg.sh prüft App und Contents/Helpers/* und bricht sonst ab
```

### Mittel (behoben)

**`ConnectionLink.swift` – kodiertes `@`/`/` im Benutzer täuschte die angezeigte Adresse (S6)**
Eine Webseite öffnet `ssh://root%40prod.bank.example%2Flogin@angreifer.example`. Die Rückfrage zeigte
`root@prod.bank.example/login@angreifer.example`, und plink fragte das Passwort für diesen Namen ab.
```swift
// Vorher
if info.contains(":") { throw .linkHasPassword }      // auf dem Rohtext
user = String(info).removingPercentEncoding
// Nachher
guard let decoded = String(info).removingPercentEncoding else { throw .invalidCharacter(.user) }
if decoded.contains(":") { throw .linkHasPassword }
if decoded.contains(";") { throw .linkHasExtras }
if decoded.contains(where: { "@/".contains($0) }) { throw .invalidCharacter(.user) }
```

**Release-Binary – Pfade mit deinem Benutzernamen (S14)**
Debug-Informationen trugen Pfade wie `/Users/<Name>/Desktop/…` in die Weitergabe.
```
// Nachher (Release)
DEPLOYMENT_POSTPROCESSING = YES; STRIP_INSTALLED_PRODUCT = YES; STRIP_STYLE = all
// make-dmg.sh sucht im ganzen Paket nach „/Users/“ und dem Benutzernamen (nur in der Bundle-ID erlaubt)
```

### Niedrig

- **Passwort im Ablehnungsdialog** (behoben): Bei `ssh://test:geheim@…` stand „geheim“ in der Meldung (RFC 3986 3.2.1).
  Jetzt keine Vorschau, sobald zwischen `://` und `@` ein `:` steht, roh oder als `%3A`.
- **Telnet-Link ohne Hinweis** (behoben): Eine Webseite kann zu einer Klartext-Anmeldung lenken; die Rückfrage sagt jetzt
  „unverschlüsselt“.
- **Agent-Schlüssel gegenüber einem Server aus einem Link** (Hinweis eingebaut, Entscheidung offen): Die Schnellverbindung
  probiert die Schlüssel im Agenten. Ein Server, zu dem eine Webseite lockt, sieht dabei ihre öffentlichen Teile und kann
  dich so wiedererkennen. Das passiert erst nach deiner Bestätigung und nach dem Hostschlüssel.
- **Lokales Netzwerk und Ad-hoc-Signatur:** macOS bindet die Freigabe an die Signatur. Eine neu gebaute, ad hoc signierte
  Fassung kann deshalb erneut fragen. Bekannt, in „Zuerst lesen“ erklärt.
- **IPv6-Zone** im Link nur als `%25` (RFC 6874), danach dieselbe Prüfung wie in der Schnellverbindung. Kein Befund.

### Geprüft ohne Befund
- **S1:** Kein Passwort aus Links; Passwörter weiter nur Schlüsselbund + Pipe.
- **S3/S4:** Benutzer und Server aus Links gehen durch `Endpoint` (kein führendes „-“, keine Steuerzeichen, Server streng
  ASCII), Start über `-load` mit einer Schnellsitzung (UUID-Name), Argumentliste ohne Shell.
- **S5:** Hostschlüssel fragt weiter plink, nichts wird angenommen.
- **S9:** Das Protokoll nennt nur die Anzahl verworfener Links, keine Adresse.
- **S11:** OSC 52 und Terminal-Links weiter nur nach Rückfrage, jetzt auch ganz abschaltbar.
- **Flut von Links:** nur der erste zählt, während einer offenen Rückfrage keine weitere.

### Zusammenfassung
Release-Signatur (hoch), die Adresstäuschung über Prozentkodierung und die Pfade im Binary (mittel) sowie drei kleine Punkte
sind behoben und getestet. Offen ist nur die Abwägung zu den Agent-Schlüsseln (unten).

## Für dich zu entscheiden

1. **Akzentfarbe:** Jetzt `#A65C00` hell und `#AD6200` dunkel. Weiße Schrift auf Standardknöpfen erreicht damit 5,1:1 bzw.
   4,6:1, vorher mit `#F2A33A` nur 2,1:1. Plan 3.1 sah dunkle Schrift auf Bernstein vor, das geht bei Systemknöpfen nicht.
   Text in der Akzentfarbe auf dunklem Grund erreicht nur etwa 3,2:1. Deshalb habe ich den einzigen Link durch einen Knopf
   ersetzt. Möglichkeiten:
   - (a) so lassen – mein Vorschlag;
   - (b) dunkle Variante `#C87414`: 3,5:1 für weiße Schrift, 4,2:1 als Text, ähnlich wie Apples eigenes Blau;
   - (c) zurück zu Bernstein, dann ist weiße Schrift auf Knöpfen schlecht lesbar.
2. **Version 0.9.0 (Build 3)** für die erste Weitergabe – passt das?
3. **Markenprüfung (Erinnerung):** Im Mac App Store fand ich keine App mit genau dem Namen „TunnelTerminal“, aber
   SSH-Werkzeuge mit ähnlichen Namen (z. B. „EasyTunnel“). Eine Registerrecherche habe ich nicht gemacht: DPMAregister und
   TMview (EUIPO), Klasse 9 (Software). Keine Rechtsberatung – vor einer öffentlichen Weitergabe bitte selbst prüfen.
4. **Über den Plan hinaus** (alle klein, getestet; behalten oder streichen?):
   - „Nie öffnen“ für Terminal-Links und für Links aus anderen Apps (S6/S11 verlangen nur die Rückfrage),
   - anpassbare Symbolleiste,
   - `NSLocalNetworkUsageDescription` samt Texten (für macOS 15 nötig, damit die Abfrage einen Grund nennt),
   - Ordner-Knöpfe unter „Erweitert“,
   - Telnet- und Agent-Hinweis in der Link-Rückfrage.
5. **Agent-Schlüssel bei Link-Verbindungen:** (a) Hinweis wie jetzt – mein Vorschlag; (b) für Links den Agenten abschalten
   (`TryAgent=0`). Dann klappt die Anmeldung mit Schlüssel aus Links nicht mehr.
6. **Standard-App festlegen** besser erst mit der installierten App aus der DMG. Aus der Debug-Fassung zeigt macOS danach
   auf den Bauordner.

**Entschieden bei der Abnahme (21.10.2026):**
1. Akzentfarbe bleibt (a): `#A65C00` / `#AD6200`.
2. Version 0.9.0 (Build 3) für die erste Weitergabe.
3. Markenprüfung: zur Kenntnis genommen („passt alles“).
4. Alles über den Plan hinaus bleibt.
5. Agent-Schlüssel bei Links: Hinweis wie jetzt (a).
6. Leonard bekommt die DMG; alle anderen Fassungen von TunnelTerminal (Bauordner, Zwischenkopien, ältere DMGs) werden
   entfernt. Sitzungen, Hostschlüssel, Einstellungen und Schlüsselbund bleiben.

## Noch nicht geprüft (kann ich nicht oder nicht sinnvoll)

- **Beglaubigung durch Apple (Notarisierung):** ohne Entwicklerkonto nicht möglich. Das erste Öffnen auf einem anderen Mac
  ist nur in „Zuerst lesen“ beschrieben, nicht ausprobiert.
- **DMG auf einem zweiten Benutzerkonto oder Mac:** nicht gemacht.
- **Safari → TunnelTerminal:** Dafür müsste ich deine Standard-App für `ssh://` ändern (jetzt Termius). Das habe ich nicht
  getan; den Weg prüfen der App-Test, `open -a` und meine Klicktests.
- **VoiceOver mit dem Ohr:** Ich kann nur den Bedienungshilfen-Baum lesen (alle Knöpfe beschriftet), nicht zuhören.
- **Menüs und Tippen in der App:** Computer-Use darf TunnelTerminal nur anklicken. Die Menüs habe ich als Liste gelesen, die
  Menü-Fenster als Bilder geprüft (`ui snap`, Hell und Dunkel).
- **fn-Kürzel aus „Bewegen & Größe ändern“:** Ein Test kann solche Einträge nicht nachbauen, weil NSMenuItem „fn“ nicht
  speichert. Pfeile und F-Tasten sind getestet.
- **Time-Profiler-Lauf:** nicht gemacht. Gemessen sind die Release-App (Start 0,15 s, 52 MB, 0,1 % CPU im Leerlauf), die
  Kurzanleitung (2 ms) und die Bauzeiten.
- **Heimserver:** nicht angefasst. Die Abfrage zum lokalen Netzwerk (macOS 15) könnte erklären, warum die Verbindung in M3
  scheiterte – bitte einmal ausprobieren.
- **Hinweis:** Ein inzwischen entfernter Test las eine Datei vom Schreibtisch. Dabei hat macOS vermutlich nach dem Zugriff
  gefragt, und jemand hat ihn erlaubt. Zurücknehmen lässt er sich unter Systemeinstellungen › Datenschutz & Sicherheit ›
  Dateien und Ordner › TunnelTerminal.

## Skill-Protokoll

| Skill | Wofür | Was es geändert hat |
|---|---|---|
| ponytail (ganzer Chat) | kleinste vollständige Lösung | Links nur Benutzer/Server/Port, kein eigenes Update-Werkzeug (Hinweis + Website), Prüfungen im DMG-Skript statt eigener Werkzeuge, Kurzanleitung als eine HTML-Quelle |
| vibe-security | eigenes Audit, Prüfer-Agent | `get-task-allow` raus, Pfade raus, Prozentkodierung, Passwort nie anzeigen, Telnet-Hinweis |
| ponytail-review | Prüfer-Agent | Link ohne Fenster, `%40`/`%2F`, schärferer Robustheitstest, Kürzel-Zeichen, DMG-Fehler, −7 Zeilen |
| code-review (mattpocock) | Standards- und Spec-Prüfer getrennt | Fußnote, Platzhalter, `private`, eine Regel für Menü und Symbolleiste, `AppLinkPrompt`, Kurzanleitung als RTF |
| apple-skills:release-review | Weitergabe | Release-Einstellungen (Signatur, Strip), Info.plist (lokales Netzwerk, URL-Schemata), „Zuerst lesen“ |
| apple-skills:legal | Lizenzen, Datenschutz | Lizenztexte im Über-Fenster aus dem Paket; keine Datenschutzerklärung nötig, weil die App keine Daten sammelt |
| apple-skills:generators (settings-screen) | Einstellungen | Reiter „Sicherheit“/„Erweitert“ mit Kopf- und Fußzeilen, Schlüssel zentral in `AppSettings` |
| apple-skills:performance | Messung | Release-App gemessen, Kurzanleitung von 0,2 s auf 2 ms, Bauzeiten |
| apple-skills:design | Entwurf B, Kontrast | Seitenleiste, Statuszeile, Einfüge-Hinweis, Akzentfarbe nachgemessen, Link → Knopf |
| swiftui / swiftui-pro | Einstellungs-Views | `Form`/`LabeledContent`, `Button` statt `Link`, `foregroundStyle`, `sizingOptions` |
| apple-skills:macos, :swift | URL-Schema, Standard-App | `CFBundleURLTypes`, `application(_:open:)`, `NSWorkspace.setDefaultApplication`, Hauptthread-Regeln |
| apple-skills:testing + mattpocock:tdd | Tests | siehe unten |
| anthropic-skills:computer-use | eigener UI-Check | Link-Rückfragen, Link ohne Fenster, Bedienungshilfen-Baum; Menüs als Liste, Menü-Fenster als Bilder |
| mattpocock:research | API-Fakten | `docs/M7-Recherche.md` (URL-Schemata, Standard-App, lokales Netzwerk, Release-Signatur, HTML-Import, PuTTY-Updates) |

**TDD, ehrlich:**
- Seams (vorher festgelegt): `ConnectionLink(parsing:)`, `PuTTYVersion.release` und `Endpoint` im Kern; in der App
  `TabCommandState.allows`, `ShortcutOverview.label/entries`, `AppLinkPrompt`, `ServerRequestPrompts(defaults:)`.
- Kern: Link-Leser und PuTTY-Version Schnitt für Schnitt. Der Test zur PuTTY-Version fand den Fehler mit „Build platform:
  Release …“. Die Korrektur nach dem Prüfer lief nachweisbar rot → grün: `m7k3` mit 4 Fehlern (`%40`, `%2F`, verschärfter
  Robustheitstest), `m7k4` grün.
- App: Die `FinishingTests` sind zusammen mit der Umsetzung entstanden, nicht streng vorher. Nach den Reviews kamen Tests
  dazu: Passwort nie im Dialog, Telnet-/Agent-Hinweis, Kürzel-Zeichen aus einem eigenen Menü, Server zuerst.
- Ein Test, der die RTF-Datei gegen die HTML-Quelle prüfte, hat die Schreibtisch-Abfrage ausgelöst (siehe oben). Ich habe
  ihn durch `Scripts/kurzanleitung.sh --pruefen` im DMG-Bau ersetzt.
