#!/bin/bash
# M4-Tempo ohne App (siehe tempo.py): Durchsatz von plink allein an ein PTY; Aufruf „tempo raw|ssh“
cd "$(dirname "$0")/../.." || exit 1
python3 build/m4/tempo.py "$HOME/Library/Caches/TunnelTerminal-Build/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/Helpers/plink" \
  "${1:-ssh}" "$HOME/Library/Application Support/TunnelTerminal/putty"
