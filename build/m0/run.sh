#!/bin/bash
# Führt build/m0/cmd.sh aus (wird je Schritt ersetzt) und legt die Ausgabe zusätzlich in build/m0/out.txt ab.
cd "$(dirname "$0")/../.." || exit 1
bash build/m0/cmd.sh 2>&1 | tee build/m0/out.txt
exit "${PIPESTATUS[0]}"
