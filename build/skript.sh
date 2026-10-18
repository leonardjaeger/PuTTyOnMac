#!/bin/bash
# Zeigt auf das aktuelle Hilfsskript (U1: Release-Prüfung). Sein Inhalt steht zur Nachvollziehbarkeit im Log.
cd "$(dirname "$0")/.." || exit 1
echo "--- build/u1/pruef.sh ---"; cat build/u1/pruef.sh; echo "---"
bash build/u1/pruef.sh
