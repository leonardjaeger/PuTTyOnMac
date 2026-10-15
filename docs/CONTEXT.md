# SSH-App – Begriffe

Glossar der App (Arbeitstitel „SSH-App“). Nur Begriffe, keine Umsetzung.

**Sitzung** – ein benannter Satz PuTTY-Einstellungen (Server, Benutzer, Port, Protokoll, Terminaltyp …) im PuTTY-Format. Gespeicherte Sitzungen kommen in M2; bis dahin entstehen Sitzungen nur vorübergehend für eine Schnellverbindung.
_Nicht:_ Verbindung, Profil.

**Schnellverbindung** – eine Verbindung aus einer eingetippten Adresse und einem Protokoll, ohne gespeicherte Sitzung.

**Adresse** – `benutzer@server:port`; Benutzer und Port sind optional, IPv6-Adressen stehen mit Port in eckigen Klammern.

**Server** – der Rechner, zu dem verbunden wird (Name oder IP-Adresse). In PuTTY „HostName“.

**Protokoll** – SSH, Telnet oder Raw (später zusätzlich Seriell). Bestimmt den Standardport; Raw hat keinen.

**Verbindung** – ein laufendes plink in einem Fenster bzw. Tab, vom Start bis zum Ende. „Erneut verbinden“ startet eine neue Verbindung mit derselben Adresse.

**Trennen** – die App beendet die Verbindung (auch während einer Abfrage von plink).

**Abfrage** – Text, mit dem plink im Terminal etwas wissen will (Hostschlüssel, Passwort, „Press Return“). Kommt von PuTTY, nicht von der App.

**Hostschlüssel** – der öffentliche Schlüssel des Servers; beim ersten Verbinden bestätigt, danach im PuTTY-Ordner gespeichert.

**PuTTY-Ordner** – der eigene Ablageordner der App für Sitzungen und Hostschlüssel, getrennt von einer anderen PuTTY-Installation.

**Profil** – Darstellung des Terminals (Schrift, Farben …), ab M4. _Nicht:_ Sitzung.
