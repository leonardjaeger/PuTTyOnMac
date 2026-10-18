# TunnelTerminal: Logo-Leitfaden (Kurzfassung)

Stand: 18.10.2026 · Richtung „Tunnel“ · App-Name **TunnelTerminal** (festgelegt am 18.10.2026). Das App-Icon bleibt ohne Namen; den Schriftzug gibt es nur in den Logo-Varianten mit Schrift (`lockup/`).

## 1. Das Zeichen

**Idee:** Zwei Torbögen bilden den SSH-Tunnel. An seinem Ende leuchtet der Cursor in Bernstein, der Farbe alter Phosphor-Terminals.

**Fassungen**

| Fassung | Datei | Einsatz |
|---|---|---|
| Hauptzeichen, Farbe auf hell | `svg/tunnel-symbol-farbe-hell.svg` | Website, Doku, README im hellen Modus |
| Hauptzeichen, Farbe auf dunkel | `svg/tunnel-symbol-farbe-dunkel.svg` | dunkle Flächen, README im dunklen Modus, App-Icon |
| Einfarbig schwarz / weiß / Tinte | `svg/tunnel-symbol-black.svg`, `-white.svg`, `-ink.svg` | Druck in einer Farbe, Gravur, Stempel |
| Kleinfassung (16-px-Raster) | `svg/tunnel-klein-*.svg` | alles unter 24 px: Favicon, 16/32-px-Icons, Menüleiste |
| App-Icon macOS | `AppIcon.appiconset/` | in der App eingesetzt (seit U1); 16 und 32 px sind die Kleinfassung |
| App-Icon macOS 26 (Liquid Glass) | `IconComposer-Ebenen/` | drei Ebenen für Apples Icon Composer |
| Web | `web/` | Favicon, Apple-Touch-Icon, Manifest, `<head>`-Ausschnitt |

Die weiße Fassung und die Fassung auf dunklem Grund haben etwas dünnere Bögen (21 statt 22 Einheiten). Hell auf Dunkel wirkt sonst fetter.

## 2. Schutzraum

Rund um das Zeichen bleibt mindestens **eine Cursorbreite** frei (28 Einheiten im 256er-Raster, rund 15 % der Zeichenbreite). Der Abstand wächst mit dem Zeichen mit.

## 3. Mindestgrößen

| Fassung | Bildschirm | Druck |
|---|---|---|
| Hauptzeichen | ab 24 px | ab 8 mm |
| Kleinfassung | 16–24 px | 5–8 mm |

Unter 24 px laufen die zwei Bögen zusammen, deshalb gibt es dort nur einen Bogen. Die Kleinfassung liegt genau auf dem 16-px-Raster und bleibt bei 16 und 32 px scharf.

## 4. Farben

| Name | Rolle | HEX | RGB | CMYK (ca.) | Pantone (ca.) |
|---|---|---|---|---|---|
| Tunnelnacht | Grund, Bögen auf hell | `#16181D` | 22 24 29 | 24 17 0 89 | Black 6 C |
| Kreide | Bögen auf dunkel | `#EEEBE4` | 238 235 228 | 0 1 4 7 | ohne Sonderfarbe (Papierweiß) |
| Bernstein | Cursor auf dunkel | `#FFB224` | 255 178 36 | 0 30 86 0 | 1235 C |
| Bernstein dunkel | Cursor auf hell | `#C77700` | 199 119 0 | 0 40 100 22 | 7563 C |

Die CMYK- und Pantone-Werte sind umgerechnete Näherungen. Vor einem echten Druckauftrag am Farbfächer prüfen.

**Kontraste:**
- Bernstein auf Tunnelnacht: 9,8 : 1
- Kreide auf Tunnelnacht: 14,9 : 1
- Bernstein dunkel auf Weiß: 3,5 : 1

Hellen Bernstein **nie auf Weiß** verwenden (1,8 : 1). Dort gilt immer Bernstein dunkel.

**Erlaubte Paare:**
- Tinte und Bernstein dunkel auf Weiß
- Kreide und Bernstein auf Tunnelnacht
- Schwarz auf Weiß
- Weiß auf Schwarz oder einem dunklen, ruhigen Foto

## 5. Schrift

Die Wortmarke „TunnelTerminal“ ist aus **Inter** (OFL) gebaut und in Pfade umgewandelt (`wordmark.py`, Ergebnisse in `lockup/`, waagrecht und gestapelt, hell und dunkel). Apples SF Pro darf nur für Oberflächen auf Apple-Plattformen genutzt werden, nicht für ein Logo.

## 6. Bitte nicht

- verzerren, drehen, spiegeln
- den Cursor vom Boden lösen oder umfärben (er ist immer Bernstein oder die Einfarb-Farbe)
- zusätzliche Zeichen wie `>_`, Schloss oder Blitz ergänzen
- Schatten, Verläufe, Konturen oder Leuchteffekte hinzufügen
- das Hauptzeichen unter 24 px einsetzen (dann die Kleinfassung nehmen)
- auf mittelhelle oder unruhige Flächen ohne Icon-Fläche legen
- Bögen und Cursor neu zeichnen statt die Masterdateien zu nutzen

## 7. Technik

- Alle Masterdateien liegen im Raster 256 × 256, sind reine Pfade (keine Schrift, keine Effekte) und wurden mit dem Logo-Audit geprüft (100/100).
- Erzeugt werden sie mit `gen.py` und `build_icons.py`. Ändert sich eine Farbe oder ein Maß, werden alle Dateien mit `python3 build_icons.py` neu erzeugt (braucht Python 3.12 oder neuer mit Pillow und cairosvg; das Python 3.9 von macOS reicht nicht). Die Logo-Varianten mit Schriftzug erzeugt `wordmark.py` (zusätzlich fontTools und die Schrift Inter).
- Es sind keine persönlichen Daten enthalten, die Beispiele nutzen nur Platzhalter (`server.example`). Die Dateien dürfen damit ins öffentliche Repo.
