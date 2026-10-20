# M5 – Machbarkeit: Tunnel, Proxy, Jump-Host, Telnet/Raw/Seriell

**Stand:** 20.10.2026 · Messskript `build/m5/machbarkeit.sh` mit `build/m5/probe.py` (lokal, nicht im Repo), plink 0.85 aus
`Scripts/build-putty.sh`, Wegwerf-sshd aus M1 auf 127.0.0.1:2222 (nur Schlüssel). plink läuft wie in der App an einem
eigenen PTY ohne Steuerterminal (`setsid`, Deskriptoren geerbt).

## 1. Port-Weiterleitungen und Proxys – funktionieren ohne Änderung

| Test | Ergebnis |
|---|---|
| `PortForwardings=L28080=127.0.0.1:28081,D28082,R28083=127.0.0.1:28081` | lokal, dynamisch (SOCKS) und entfernt liefern die Testseite |
| `ProxyMethod=2` (SOCKS 5) über die dynamische Weiterleitung | Anmeldung über den Proxy |
| `ProxyMethod=3` (HTTP CONNECT, Test-Proxy) | Proxy sieht `CONNECT 127.0.0.1:2222`, Anmeldung klappt |
| `ProxyMethod=6`, `ProxyHost=Sprung/Mac` (Name einer gespeicherten Sitzung) | plink meldet „Making proxy SSH connection …“ und „Making primary SSH connection …“, sshd zählt zwei Anmeldungen |

Format von `PortForwardings` (settings.c, `wmap`/`gppmap`): Einträge durch „,“ getrennt, `=`, `,` und `\` mit `\` maskiert;
Schlüssel `[4|6][L|R][bindadresse:]port`, Wert `ziel:port`; dynamisch als Schlüssel `D[bindadresse:]port` mit leerem Wert.
plink liest die Liste in eine sortierte Tabelle (doppelte Schlüssel: der letzte gilt) und schreibt sie sortiert.

**Fallen:**
- **Ziele auf diesem Mac umgehen jeden Proxy:** PuTTY leitet Verbindungen zu `localhost`/127.0.0.1 standardmäßig nicht über
  den Proxy (`ProxyLocalhost=0`). Ohne `ProxyLocalhost=1` liefen die Tests oben scheinbar „über den Proxy“, tatsächlich direkt.
  Die App zeigt das im Editor als Hinweis.
- **Belegter lokaler Port:** plink meldet ihn nur mit `-v` („Local port … forwarding … failed: Address already in use“),
  ohne `-v` verbindet es still ohne diese Weiterleitung. Mit `-v` käme das ganze Ereignisprotokoll ins Terminal. Deshalb
  prüft die App vor dem Start selbst, ob der lokale Port frei ist (Hinweis im Terminal und im Inspektor).
- Weitere Statusmeldungen zu Weiterleitungen gibt plink ohne `-v` nicht aus – der Inspektor zeigt deshalb die eingerichteten
  Weiterleitungen und den Port-Hinweis, keinen Live-Status.

## 2. Terminalmodus bei Seriell, Telnet und Raw

Getippt wird „abc“ ohne Return, dann Ctrl-C (0x03), dann Return.

| Verbindung | „abc“ sofort beim Gegenüber | lokales Echo | Ctrl-C beim Gegenüber | Return |
|---|---|---|---|---|
| Seriell, plink 0.85 unverändert | nein (erst mit Return) | ja | nein | `\n` |
| **Seriell mit Patch 0002** | **ja** | **nein** | **ja** | **`\r`** |
| Telnet (Server verhandelt ECHO + SGA) | ja | nein | ja | `\r\0` |
| Raw | nein (Zeilenmodus) | ja | nein | `\n` |

**Ursache Seriell:** `unix/plink.c` meldet den Modus der Leitungsdisziplin, bevor `local_tty` gesetzt ist (die Meldung geht
verloren), und setzt danach fest „Echo + Zeilenpuffer“. SSH und Telnet melden später erneut, Seriell nie.
**Entscheidung 20.10.2026 (Leonard):** Patch nur für Seriell (`Scripts/putty-patches/0002-seriell-ohne-lokales-echo.patch`),
SSH, Telnet und Raw bleiben unverändert. Gemessen nach dem Patch: Zeile „Seriell mit Patch 0002“.

**Raw** bleibt im Zeilenmodus mit lokalem Echo: Das ist PuTTYs Standard für Raw (`raw_ldisc`: Echo und Bearbeitung „an“
bei Einstellung „Automatisch“). Ctrl-C erreicht den Server dabei nicht (ohne Steuerterminal löst es nichts aus) und
`LocalEcho`/`LocalEdit` „aus“ wirkt in plink 0.85 nicht (M4-Machbarkeit 2) – bewusst so belassen und dokumentiert.

**Telnet** arbeitet nach der Verhandlung im Zeichenmodus; Echo kommt vom Server.

## 3. Seriell auf macOS

plink 0.85 (unix/serial.c): Geschwindigkeit wird auf den nächstkleineren Standardwert (B50 … B4000000, soweit vorhanden)
abgerundet; Datenbits 5–8; Stoppbits „2“ ab `SerialStopHalfbits` ≥ 4, sonst 1; Parität nur keine/ungerade/gerade
(Mark und Space wirken wie keine); Flusskontrolle keine, XON/XOFF, RTS/CTS (DSR/DTR wirkt wie keine). Gestartet wird nur
mit nicht leerem `SerialLine` (`conf_launchable`). Ein echter USB-Seriell-Adapter war nicht vorhanden; geprüft mit einem
PTY-Paar als Gerät (Prüfpunkt mit 115200 Baud bleibt offen).

## 4. Nachträge aus Oberflächenprüfung und Reviews (20.10.2026)

- **Weiterleitungen erst nach „Press Return to begin session“:** plink zeigt die Echtheitsabfrage (Antispoof, seit M1 bewusst
  an) auch nach reiner Schlüssel-Anmeldung, weil es „Using username …“ ausgegeben hat. Gemessen (`build/m5/antispoof.sh`):
  vor Return liefert die lokale Weiterleitung nichts (curl Fehler 7), nach Return die Testseite. Die App sagt das im
  Inspektor und im Editor. Ob `-no-antispoof` für Sitzungen mit Weiterleitungen sinnvoll ist, entscheidet Leonard (Prüfliste).
- **Proxy-Schleife:** Eine Sitzung, die sich selbst (oder über andere) als SSH-Proxy nennt, lässt plink ohne jede Meldung
  hängen (`build/m5/schleife.sh`: nach 15 s noch keine Ausgabe). Die App erkennt Schleifen vor dem Verbinden und verbindet
  nicht.
- **`\` am Ende von `PortForwardings`:** plinks `gppmap` liest danach über das Ende des Werts hinaus (Quelltext; gemessen
  ohne Absturz). Die App verbindet mit solchen Sitzungen nicht („beschädigt“). Meldung an das PuTTY-Team empfohlen.
- **Unbestimmter Proxy:** Ist weder `ProxyMethod` (0–8) noch das alte `ProxyType` (0–4) gültig, bleibt in plink der
  Proxy-Wert ungesetzt (settings.c). Die App verbindet dann nicht und gibt kein gespeichertes Passwort heraus.
- **Bindadresse öffnet Ports:** Eine Zahl-Bindadresse (z. B. `D0.0.0.0:1080`) ersetzt „nur localhost“ (unix/network.c,
  `sk_newlistener` mit `AI_NUMERICHOST`) – Warnung wie bei `LocalPortAcceptAll`, beim Import nicht vorausgewählt.
- **plink lauscht auf ::1 und 127.0.0.1:** Die Port-Prüfung der App prüft beide.
