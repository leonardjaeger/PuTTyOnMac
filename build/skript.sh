#!/bin/bash
# Zeigt auf das aktuelle Meilenstein-Skript (M1). Inhalt von cmd.sh steht zur Nachvollziehbarkeit im Log.
cd "$(dirname "$0")/.." || exit 1
echo "--- build/m1/cmd.sh ---"; cat build/m1/cmd.sh; echo "---"
bash build/m1/cmd.sh
