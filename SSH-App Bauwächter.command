#!/bin/bash
# Doppelklick startet den Bauwächter der SSH-App in einem Terminal-Fenster.
cd "$(dirname "$0")" || exit 1
exec bash Scripts/watch.sh
