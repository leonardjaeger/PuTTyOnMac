#!/bin/bash
# Zeigt auf das aktuelle Hilfsskript (Härtung; Skript und Schritt stehen in build/haertung/schritt.txt, nicht im Repo).
# Sein Inhalt steht zur Nachvollziehbarkeit im Log.
cd "$(dirname "$0")/.." || exit 1
read -r datei schritt rest < build/haertung/schritt.txt
case "$datei" in *[!A-Za-z0-9_-]*|"") echo "ungültiger Skriptname"; exit 2 ;; esac
echo "--- build/haertung/$datei.sh $schritt $rest ---"; cat "build/haertung/$datei.sh"; echo "---"
bash "build/haertung/$datei.sh" $schritt $rest
