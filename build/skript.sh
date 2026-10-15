#!/bin/bash
# Zeigt auf das aktuelle Meilenstein-Skript. Für M1 auf build/m1/run.sh umbiegen.
cd "$(dirname "$0")/.." || exit 1
bash build/m0/run.sh
