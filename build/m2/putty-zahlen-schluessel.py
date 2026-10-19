#!/usr/bin/env python3
"""Erzeugt die Liste der Zahlen-Einstellungen (Windows: REG_DWORD) aus PuTTYs conf.h, settings.c und windows/storage.c.
Aufruf: python3 build/m2/putty-zahlen-schluessel.py <putty-quellordner>   (Ausgabe: Swift-Mengenliteral)"""
import re, sys
src = sys.argv[1]
strip = lambda t: re.sub(r'/\*.*?\*/', '', t, flags=re.S)
conf = strip(open(f'{src}/conf.h').read())
keys = set()
for m in re.finditer(r'CONF_OPTION\((\w+),(.*?)\n\)', conf, re.S):
    body = m.group(2)
    kw = re.search(r'SAVE_KEYWORD\("([^"]+)"\)', body)
    vt = re.search(r'VALUE_TYPE\((\w+)\)', body)
    if kw and vt and vt.group(1) in ('INT', 'BOOL') and 'SUBKEY_TYPE' not in body:
        keys.add(kw.group(1))
    if kw and vt and vt.group(1) == 'FONT':   # windows/storage.c write_setting_fontspec
        keys |= {kw.group(1) + s for s in ('IsBold', 'CharSet', 'Height')}
settings = strip(open(f'{src}/settings.c').read())
keys |= set(re.findall(r'write_setting_[ib]\(sesskey,\s*"([^"]+)"', settings))
# auch nur gelesene, ältere Zahlen-Schlüssel (z. B. ProxyType, BugDHGEx2)
keys |= set(re.findall(r'gpp[ib](?:_raw)?\(sesskey,\s*"([^"]+)"', settings))
print(len(keys), file=sys.stderr)
print(', '.join(f'"{k}"' for k in sorted(keys)))
