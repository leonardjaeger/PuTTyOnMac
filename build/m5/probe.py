#!/usr/bin/env python3
"""M5-Machbarkeit: plink an einem eigenen PTY wie in der App (setsid, kein Steuerterminal).
Aufruf: probe.py serial|telnet|raw <plink> <puttydir>   ·   probe.py httpproxy <port> (läuft bis kill)"""
import os, sys, time, socket, select, threading, subprocess

def read_all(fd, wait=0.6):
    out = b""; end = time.time() + wait
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], max(0, end - time.time()))
        if not r: break
        try: chunk = os.read(fd, 4096)
        except OSError: break
        if not chunk: break
        out += chunk
    return out

def start_plink(plink, puttydir, session):
    m, s = os.openpty()
    env = {"PUTTYDIR": puttydir, "TERM": "xterm-256color", "HOME": os.environ["HOME"], "LANG": "en_US.UTF-8"}
    p = subprocess.Popen([plink, "-load", session], stdin=s, stdout=s, stderr=s, env=env, start_new_session=True, close_fds=True)
    os.close(s)
    return p, m

def session(puttydir, name, text):
    path = os.path.join(puttydir, "sessions", name)
    with open(path, "w") as f: f.write(text)
    os.chmod(path, 0o600)

def check_terminal(label, m, peer_read, peer_write):
    """Tippt ohne Return, prüft, ob es sofort beim Gegenüber ankommt und ob plink lokal echot; dann ^C und Return."""
    print(f"  Start-Ausgabe: {read_all(m, 1.0)!r}")
    os.write(m, b"abc")
    time.sleep(0.6)
    got = peer_read(); echo = read_all(m)
    print(f"  {label}: 'abc' ohne Return beim Gegenüber: {got!r}; lokales Echo im Terminal: {echo!r}")
    os.write(m, b"\x03")
    time.sleep(0.6)
    print(f"  ^C (0x03) beim Gegenüber: {peer_read()!r}")
    os.write(m, b"\r")
    time.sleep(0.6)
    print(f"  nach Return beim Gegenüber: {peer_read()!r}")
    peer_write(b"VOM-GEGENUEBER\r\n")
    time.sleep(0.6)
    print(f"  Ausgabe im Terminal: {read_all(m)!r}")

def serial(plink, puttydir):
    dm, ds = os.openpty()          # „Gerät“: plink öffnet die Slave-Seite als SerialLine
    line = os.ttyname(ds)
    session(puttydir, "ser", f"Protocol=serial\nSerialLine={line}\nSerialSpeed=115200\nSerialDataBits=8\n"
            "SerialStopHalfbits=2\nSerialParity=0\nSerialFlowControl=0\nTerminalType=xterm-256color\n")
    p, m = start_plink(plink, puttydir, "ser")
    check_terminal("Seriell", m, lambda: read_all(dm), lambda b: os.write(dm, b))
    p.terminate(); p.wait(5); print(f"  plink beendet: {p.returncode}")

def network(plink, puttydir, proto, negotiate):
    srv = socket.socket(); srv.bind(("127.0.0.1", 0)); srv.listen(1)
    port = srv.getsockname()[1]
    session(puttydir, proto, f"Protocol={proto}\nHostName=127.0.0.1\nPortNumber={port}\nTerminalType=xterm-256color\n")
    p, m = start_plink(plink, puttydir, proto)
    srv.settimeout(5); c, _ = srv.accept(); c.setblocking(False)
    if negotiate:   # IAC WILL ECHO, IAC WILL SGA: Server echot, Zeichenmodus (wie ein echter telnetd)
        c.sendall(bytes([255, 251, 1, 255, 251, 3])); time.sleep(0.5)
    def rd():
        try: data = c.recv(4096)
        except BlockingIOError: return b""
        return data
    print(f"  Verhandlung vom Client: {rd()!r}")
    check_terminal(proto, m, rd, lambda b: c.sendall(b))
    p.terminate(); p.wait(5); print(f"  plink beendet: {p.returncode}")

def httpproxy(port):
    """Kleinster HTTP-CONNECT-Proxy für den Test (nur 127.0.0.1)."""
    srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", port)); srv.listen(4)
    def pipe(a, b):
        try:
            while True:
                d = a.recv(65536)
                if not d: break
                b.sendall(d)
        except OSError: pass
        for s in (a, b):
            try: s.shutdown(socket.SHUT_RDWR)
            except OSError: pass
    def handle(c):
        req = b""
        while b"\r\n\r\n" not in req: req += c.recv(4096)
        target = req.split(b" ")[1].decode(); host, tport = target.rsplit(":", 1)
        print(f"CONNECT {target}", flush=True)
        u = socket.create_connection((host, int(tport)))
        c.sendall(b"HTTP/1.1 200 Connection established\r\n\r\n")
        threading.Thread(target=pipe, args=(c, u), daemon=True).start(); pipe(u, c)
    while True:
        c, _ = srv.accept(); threading.Thread(target=handle, args=(c,), daemon=True).start()

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "serial": serial(sys.argv[2], sys.argv[3])
    elif mode == "telnet": network(sys.argv[2], sys.argv[3], "telnet", True)
    elif mode == "raw": network(sys.argv[2], sys.argv[3], "raw", False)
    elif mode == "httpproxy": httpproxy(int(sys.argv[2]))
