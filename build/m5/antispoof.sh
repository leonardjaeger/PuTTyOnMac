#!/bin/bash
# M5: Stehen Weiterleitungen schon vor plinks „Press Return to begin session“? (plink an einem PTY wie in der App)
set -u
cd "$(dirname "$0")/../.." || exit 1
cache="$HOME/Library/Caches/TunnelTerminal-Build"
putty="$HOME/Library/Application Support/TunnelTerminal/putty"
python3 - "$cache/DerivedData/Build/Products/Debug/TunnelTerminal.app/Contents/Helpers/plink" "$putty" <<'PY'
import os, sys, time, subprocess, select
plink, putty = sys.argv[1], sys.argv[2]
m, s = os.openpty()
p = subprocess.Popen([plink, "-load", "M5/Tunnel"], stdin=s, stdout=s, stderr=s, start_new_session=True,
                     env={"PUTTYDIR": putty, "HOME": os.environ["HOME"], "TERM": "xterm-256color"})
os.close(s)
def out():
    data = b""
    while select.select([m], [], [], 0.3)[0]:
        data += os.read(m, 4096)
    return data.decode(errors="replace").replace(os.environ.get("USER", "?"), "(Benutzer)")
def curl():
    r = subprocess.run(["curl", "-s", "-m", "3", "http://127.0.0.1:28180/"], capture_output=True, text=True)
    return r.stdout.strip() or f"FEHLER {r.returncode}"
time.sleep(3); print("Ausgabe:", repr(out())); print("vor Return:", curl())
os.write(m, b"\r"); time.sleep(2); print("Ausgabe:", repr(out()[:80])); print("nach Return:", curl())
p.terminate(); p.wait(5)
PY
