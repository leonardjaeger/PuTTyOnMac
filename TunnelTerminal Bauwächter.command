#!/bin/bash
# Doppelklick startet den Bauwächter von TunnelTerminal in einem Terminal-Fenster.
cd "$(dirname "$0")" || exit 1
exec bash Scripts/watch.sh
