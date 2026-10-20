#!/usr/bin/env python3
"""M6-Machbarkeit: startet ein Programm wie die App (eigene Sitzung, PTY als 0/1/2 ohne Steuerterminal, umask 077,
optional fd 3) und zeichnet die Ausgabe mit Zeitstempeln auf. Aufruf: probe.py <hup-nach-sek|0> <aufzeichnung> <cmd …>"""
import os, select, signal, subprocess, sys, time

hup = float(sys.argv[1]); record = sys.argv[2]; cmd = sys.argv[3:]
master, slave = os.openpty()
os.umask(0o077)
start = time.time()
child = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, start_new_session=True, close_fds=True)
os.close(slave)
chunks = []
sent_hup = False
while True:
    if hup and not sent_hup and time.time() - start >= hup:
        child.send_signal(signal.SIGHUP); sent_hup = True
    ready, _, _ = select.select([master], [], [], 0.1)
    if ready:
        try:
            data = os.read(master, 65536)
        except OSError:
            data = b""
        if not data:
            break
        chunks.append((time.time() - start, data))
    elif child.poll() is not None:
        # Rest lesen
        try:
            while True:
                r, _, _ = select.select([master], [], [], 0.2)
                if not r: break
                d = os.read(master, 65536)
                if not d: break
                chunks.append((time.time() - start, d))
        except OSError:
            pass
        break
code = child.wait()
with open(record, "wb") as f:
    for t, d in chunks:
        f.write(b"%.2f " % t + d.replace(b"\r", b"<CR>").replace(b"\n", b"<LF>\n") + b"\n")
raw = b"".join(d for _, d in chunks)
updates = raw.count(b"\r") - raw.count(b"\r\n")
print("  exit=%s dauer=%.2fs ausgabe=%dB cr-updates=%d hup=%s" % (code, time.time() - start, len(raw), updates, sent_hup))
text = raw.decode("utf-8", "replace").replace("\r\n", "\n")
lines = [l for l in text.replace("\r", "\n").split("\n") if l.strip()]
for l in lines[:3] + (["…"] if len(lines) > 6 else []) + (lines[-3:] if len(lines) > 3 else []):
    print("   |", l)
