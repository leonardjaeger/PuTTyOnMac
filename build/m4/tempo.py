# M4-Tempo ohne App: Ausgabe über plink an ein PTY, so schnell wie möglich gelesen (Python, nur lokal).
#   tempo.py <plink> raw            – 13 MB von einem lokalen Socket über plink -raw
#   tempo.py <plink> ssh <puttydir> – „seq 1 1000000“ über die Testsitzung M4/Test (Wegwerf-sshd auf 127.0.0.1:2222)
# Höchstens 100 s je Messung; nach 2 s ein Return (plink wartet nach der Anmeldung auf „Press Return to begin session“).
import os, pty, select, socket, subprocess, sys, threading, time, tempfile
plink, mode = sys.argv[1], sys.argv[2]
def measure(args, env):
    master, slave = pty.openpty()
    t = time.time()
    p = subprocess.Popen([plink] + args, stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True)
    os.close(slave); n = 0; first = None; returned = False
    while time.time() - t < 100:
        if not returned and time.time() - t > 2:
            os.write(master, b"\r"); returned = True
        r, _, _ = select.select([master], [], [], 0.5)
        if not r:
            if p.poll() is not None: break
            continue
        try: b = os.read(master, 65536)
        except OSError: break
        if not b: break
        if first is None and n > 100_000: first = time.time()
        n += len(b)
    p.kill(); p.wait(); end = time.time()
    rate = (n - 100_000) / 1e6 / (end - first) if first else 0
    print(f"plink {mode}: {n/1e6:.1f} MB in {end - t:.2f} s, ab dem ersten Datenblock {rate:.2f} MB/s", flush=True)
if mode == "raw":
    payload = b"".join(b"Zeile %d\n" % i for i in range(1, 1_000_001))
    srv = socket.socket(); srv.bind(("127.0.0.1", 0)); srv.listen(1); port = srv.getsockname()[1]
    def serve():
        c, _ = srv.accept(); c.sendall(payload); c.close()
    threading.Thread(target=serve, daemon=True).start()
    d = tempfile.mkdtemp(); os.makedirs(d + "/sessions")
    measure(["-raw", "-P", str(port), "127.0.0.1"], {"PUTTYDIR": d, "HOME": os.environ["HOME"]})
else:
    measure(["-load", "M4/Test", "-t", "seq 1 1000000"], {"PUTTYDIR": sys.argv[3], "HOME": os.environ["HOME"], "TERM": "xterm-256color"})
