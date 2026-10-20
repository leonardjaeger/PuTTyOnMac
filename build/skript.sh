#!/bin/bash
# Zeigt auf das aktuelle Hilfsskript (M7; Skript und Schritt stehen in build/m7/schritt.txt, nicht im Repo).
# Sein Inhalt steht zur Nachvollziehbarkeit im Log.
cd "$(dirname "$0")/.." || exit 1
read -r datei schritt rest < build/m7/schritt.txt
case "$datei" in *[!A-Za-z0-9_-]*|"") echo "ungültiger Skriptname"; exit 2 ;; esac
echo "--- build/m7/$datei.sh $schritt $rest ---"; cat "build/m7/$datei.sh"; echo "---"
bash "build/m7/$datei.sh" $schritt $rest
