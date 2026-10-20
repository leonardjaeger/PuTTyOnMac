# TunnelTerminal – Begriffe

Glossar der App TunnelTerminal (Name seit U1, 18.10.2026). Nur Begriffe, keine Umsetzung.

**Sitzung** – ein benannter Satz PuTTY-Einstellungen (Server, Benutzer, Port, Protokoll, Terminaltyp …) im PuTTY-Format. Eine **gespeicherte Sitzung** bleibt, bis man sie löscht; eine Schnellverbindung erzeugt nur eine vorübergehende.
_Nicht:_ Verbindung, Profil.

**Sitzungsname** – der Name einer gespeicherten Sitzung, wie PuTTY ihn kennt. Er enthält die Gruppe: „Gruppe/Titel“.

**Gruppe** – Ordner in der Liste der Sitzungen; eine Ebene. Steht im Sitzungsnamen vor dem letzten „/“. Eine Sitzung ohne „/“ hat keine Gruppe.

**Titel** – der Teil des Sitzungsnamens hinter dem letzten „/“; so steht die Sitzung in der Liste.

**Standardeinstellungen** – die Sitzung „Default Settings“ von PuTTY: Vorlage für neue Sitzungen. Steht immer oben in der Liste und lässt sich nicht umbenennen.

**Import** – Sitzungen aus einer anderen PuTTY-Installation übernehmen: aus einem PuTTY-Ordner (Mac, Linux) oder aus einer Registrierungsdatei (`.reg`) von Windows-PuTTY. Vorher zeigt die App eine Liste mit Warnungen.

**Export** – gespeicherte Sitzungen als Registrierungsdatei für Windows-PuTTY oder als PuTTY-Ordner ausgeben.

**Warnung** – Hinweis auf eine Einstellung einer Sitzung, die mehr tut als verbinden: ein lokaler Proxy-Befehl (startet ein Programm auf dem Mac), eine eigene GSSAPI-Bibliothek (wird in plink geladen), ein entfernter Befehl, Agent-Weiterleitung, Port-Weiterleitungen, ein Sitzungsprotokoll, fest eingetragene Hostschlüssel oder ein SSH-Proxy.

**Gefährlich** – eine Warnung, bei der etwas auf dem Mac ausgeführt wird (lokaler Proxy-Befehl, eigene GSSAPI-Bibliothek), auch über eine Proxy-Sitzung. Vor jedem Verbinden fragt die App nach.

**Proxy-Sitzung** – gespeicherte Sitzung, deren Namen eine andere Sitzung als SSH-Proxy angibt; PuTTY lädt dann deren Einstellungen (sonst die Standardeinstellungen).

**Schnellverbindung** – eine Verbindung aus einer eingetippten Adresse und einem Protokoll, ohne gespeicherte Sitzung.

**Adresse** – `benutzer@server:port`; Benutzer und Port sind optional, IPv6-Adressen stehen mit Port in eckigen Klammern.

**Server** – der Rechner, zu dem verbunden wird (Name oder IP-Adresse). In PuTTY „HostName“.

**Protokoll** – SSH, Telnet oder Raw (später zusätzlich Seriell). Bestimmt den Standardport; Raw hat keinen.

**Verbindung** – ein laufendes plink in einem Fenster bzw. Tab, vom Start bis zum Ende. „Erneut verbinden“ startet eine neue Verbindung mit derselben Adresse bzw. Sitzung.

**Trennen** – die App beendet die Verbindung (auch während einer Abfrage von plink).

**Abfrage** – Text, mit dem plink im Terminal etwas wissen will (Hostschlüssel, Passwort, „Press Return“). Kommt von PuTTY, nicht von der App.

**Hostschlüssel** – der öffentliche Schlüssel des Servers; beim ersten Verbinden bestätigt, danach im PuTTY-Ordner gespeichert.

**PuTTY-Ordner** – der eigene Ablageordner der App für Sitzungen und Hostschlüssel, getrennt von einer anderen PuTTY-Installation.

**Hauptfenster** – ein Fenster bzw. Tab der App (Gerüst B „Werkbank“, seit M2): links die Seitenleiste, in der Mitte die Startansicht oder das Terminal, rechts der Inspektor. Jeder Tab hat seine eigene Seitenleiste; die gespeicherten Sitzungen sind für alle dieselben.

**Seitenleiste** – oben die Schnellverbindung, darunter die gespeicherten Sitzungen nach Gruppen mit Status (verbunden/getrennt), unten Knöpfe zum Anlegen und Bearbeiten.

**Inspektor** – rechte Spalte mit Angaben zur Verbindung des Tabs; zeigt nur Abschnitte von Funktionen, die es schon gibt.

**Startansicht** – Inhalt eines Tabs, der noch nicht verbunden hat. Eine Verbindung aus der Seitenleiste öffnet sich in diesem Tab; ist er schon verbunden, in einem neuen Tab daneben.

**Status** – „verbunden“, solange mindestens ein Tab die gespeicherte Sitzung offen hat.

**Profil** – Darstellung des Terminals (Schrift, Farben …), ab M4. _Nicht:_ Sitzung.

**Dateiübertragung** – Hoch- oder Herunterladen von Dateien zwischen diesem Mac und dem Server einer SSH-Verbindung, über pscp (SFTP) mit den Einstellungen der Sitzung des Tabs (ab M6). Läuft neben dem Terminal, nicht darin. _Nicht:_ SFTP-Browser.

**Zielordner** – Ordner auf dem Server, in den hochgeladen wird; eingetippt, weil pscp das aktuelle Verzeichnis der Shell nicht kennt. Leer = persönlicher Ordner des Benutzers auf dem Server.

**Teildatei** – versteckte Datei neben der Zieldatei, in die pscp beim Herunterladen schreibt. Erst nach Erfolg ersetzt sie die Zieldatei; bei Abbruch oder Fehler wird sie entfernt.
