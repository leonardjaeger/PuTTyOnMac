#!/bin/bash
# Für Claude (VM): Ergebnis eines Auftrags kurz: Status, Fehler/Warnungen (ohne Pfade mit Benutzernamen), Testsummen.
n="$1"; L="$HOME/mnt/TunnelTerminal-Build/waechter/logs"
echo "status $(cat "$L/status-$n.txt" 2>/dev/null)"
grep -E "(error|warning): |✘|Test run with|Executed [0-9]+ test|\*\* (BUILD|TEST) |failed \(|XCTAssert|Testing failed" "$L/$n.log" \
  | awk 'length($0) < 600' | grep -v appintents | sed -E "s#/Users/[^/]+/#~/#g" | sort -u | head -${2:-40}
