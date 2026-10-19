#!/bin/bash
# Zeigt auf das aktuelle Hilfsskript (M2: Oberflächenprüfung; Schritt steht in build/m2/schritt.txt, nicht im Repo).
# Sein Inhalt steht zur Nachvollziehbarkeit im Log.
cd "$(dirname "$0")/.." || exit 1
schritt="$(cat build/m2/schritt.txt 2>/dev/null)"
echo "--- build/m2/ui.sh $schritt ---"; cat build/m2/ui.sh; echo "---"
bash build/m2/ui.sh "$schritt"
