#!/bin/bash
# Zeigt auf das aktuelle Hilfsskript (M3; Skript und Schritt stehen in build/m3/schritt.txt, nicht im Repo).
# Sein Inhalt steht zur Nachvollziehbarkeit im Log.
cd "$(dirname "$0")/.." || exit 1
read -r datei schritt < build/m3/schritt.txt
case "$datei" in *[!A-Za-z0-9_-]*|"") echo "ungültiger Skriptname"; exit 2 ;; esac
echo "--- build/m3/$datei.sh $schritt ---"; cat "build/m3/$datei.sh"; echo "---"
bash "build/m3/$datei.sh" $schritt
