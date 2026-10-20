#!/bin/bash
# M4-Tempo: SwiftTerm-Parser im Debug- und Release-Bau (build/m4/bench, Ergebnis im Cache)
cd "$(dirname "$0")/bench" || exit 1
for c in debug release; do
  xcrun swift build -c $c --scratch-path "$HOME/Library/Caches/TunnelTerminal-Build/m4-bench" 2>&1 | grep -E "error|warning: unre" | head -5
  printf '%s: ' "$c"; "$HOME/Library/Caches/TunnelTerminal-Build/m4-bench/$c/bench"
done
