# Gruppen stehen im Sitzungsnamen („Gruppe/Titel“)

PuTTY kennt keine Gruppen. Wir legen die Gruppe deshalb in den Sitzungsnamen (vor das letzte „/“) und nicht in einen eigenen Schlüssel der Sitzungsdatei (wie KiTTYs `Folder`). Grund: PuTTY für Unix schreibt beim Sichern einer Sitzung nur die Schlüssel, die es kennt; ein eigener Schlüssel ginge verloren, sobald jemand die Sitzung in Homebrew-PuTTY ändert. Ein Name mit „/“ übersteht Windows-PuTTY (Registrierung), Unix-PuTTY (Dateiname `%2F`) und `plink -load` unverändert; in PuTTY selbst erscheint er als „Gruppe/Titel“ in der flachen Liste.

**Folgen:** nur eine Gruppenebene in der Oberfläche (HIG: höchstens zwei Ebenen in der Seitenleiste); Umgruppieren ist ein Umbenennen der Sitzung; Sitzungsnamen dürfen kein leeres Segment („a//b“) und kein „/“ am Rand haben.
