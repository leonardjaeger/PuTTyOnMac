#!/bin/bash
# M2: erzeugt die Importquellen für die Oberflächenprüfung (nur Platzhalter und 127.0.0.1, S14).
#   Testquellen/windows-export.reg  – wie regedit: UTF-16LE mit BOM und CRLF
#   Testquellen/putty-ordner/       – wie ~/.config/putty von PuTTY für macOS/Linux (Homebrew)
set -eu
cd "$(dirname "$0")"
mkdir -p Testquellen/putty-ordner/sessions
python3 -I - <<'PY'
reg = r'''Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\Default%20Settings]
"Present"=dword:00000001
"TerminalType"="xterm-256color"

[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\Windows/Testserver]
"Present"=dword:00000001
"HostName"="127.0.0.1"
"PortNumber"=dword:000008ae
"Protocol"="ssh"
"UserName"=""
"TerminalType"="xterm-256color"
"Colour0"="187,187,187"
"WinTitle"=""

[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\Windows/Proxy%20mit%20Befehl]
"Present"=dword:00000001
"HostName"="server.example"
"PortNumber"=dword:00000016
"Protocol"="ssh"
"ProxyMethod"=dword:00000005
"ProxyTelnetCommand"="echo Testbefehl"

[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\Windows/Mit%20Befehl]
"Present"=dword:00000001
"HostName"="192.0.2.10"
"UserName"="test"
"RemoteCommand"="uptime"
"AgentFwd"=dword:00000001
"Binaer"=hex:01,02,03

[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\-Option]
"HostName"="server.example"

[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\SshHostKeys]
"ssh-ed25519@22:server.example"="0x1"

'''
with open('Testquellen/windows-export.reg', 'wb') as f:
    f.write(b'\xff\xfe' + reg.replace('\n', '\r\n').encode('utf-16-le'))
with open('Testquellen/putty-ordner/sessions/Unix%2FTestserver', 'w') as f:
    f.write('HostName=127.0.0.1\nPortNumber=2222\nProtocol=ssh\nUserName=\nTerminalType=xterm-256color\n'
            'ZukunftsSchluessel=bleibt\n')
PY
chmod 700 Testquellen/putty-ordner Testquellen/putty-ordner/sessions
chmod 600 Testquellen/putty-ordner/sessions/*
ls -lR Testquellen | sed "s#$HOME#~#"
