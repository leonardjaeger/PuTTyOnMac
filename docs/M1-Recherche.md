# M1 – Recherche (PuTTY 0.85)

Stand: 15.10.2026
Quelle: geprüfter Quellcode `build/putty-src/` (version.h: `RELEASE 0.85`). Alle Pfade relativ zu `putty-src/`. Zeilenangaben ohne „ca.“ sind per `grep -n`/`sed -n` direkt abgelesen; „ca.“ = aus dem Ausdruck abgezählt, Abweichung ±2 Zeilen möglich.
Kennzeichnung: **[Code]** = direkt im Code belegt · **[abgeleitet]** = aus dem Codepfad geschlossen, im M1-Test bestätigen · **[offen]** = in dieser Recherche nicht geprüft.

---

## 1. `unix/storage.c` – Sitzungsdateien und `sshhostkeys`

### 1.1 Sitzungsname → Dateiname

`unix/storage.c:35–60` (`make_session_filename`)

```c
static const char hex[16] = "0123456789ABCDEF";          /* :35 */
    if (!in || !*in)
        in = "Default Settings";                          /* :39-40 */
        if (*in!='+' && *in!='-' && *in!='.' && *in!='@' && *in!='_' &&
            !(*in >= '0' && *in <= '9') &&
            !(*in >= 'A' && *in <= 'Z') &&
            !(*in >= 'a' && *in <= 'z')) {
            put_byte(out, '%');
            put_byte(out, hex[((unsigned char) *in) >> 4]);
            put_byte(out, hex[((unsigned char) *in) & 15]);  /* :49-55 */
```

- **Unverändert bleiben genau:** `+ - . @ _`, `0–9`, `A–Z`, `a–z` (nur ASCII). [Code]
- **Alles andere** (auch Leerzeichen, `%`, `/`, `:`, `,`, jedes Byte ≥ 0x80) → `%XX`, **Hex in Großbuchstaben**, byteweise (UTF-8-Namen werden pro Byte kodiert). [Code]
- **Leerer Name oder NULL** → `"Default Settings"` → Datei `Default%20Settings`. [Code]
- Rückweg `decode_session_filename` `:62–79`: `i = in[1]-'0'; i -= (i > 9 ? 7 : 0);` – das ist nur für `0–9`/`A–F` korrekt. Kleinbuchstaben-Hex (`%2f`) wird **nicht abgelehnt, sondern falsch dekodiert**; kein Gültigkeitscheck. Die App muss also exakt Großbuchstaben schreiben. [Code]
- Aufzählung `enum_dir_next` `:562–593`: nur reguläre Dateien (`stat` + `S_ISREG`, ca. `:584–585`), Name wird dekodiert. [Code]

Verzeichnisauflösung `make_filename` `:81–233`:
- `INDEX_DIR` `:89–162`: `$PUTTYDIR` gewinnt immer; sonst `$XDG_CONFIG_HOME/putty` bzw. `~/.config/putty`, **nur wenn es existiert** (`access(..., F_OK)`); sonst `~/.putty` (über `$HOME`, dann `pw_dir`, dann `/.putty`); ohne `XDG_DEFAULT` ist der Neuanlage-Standard `~/.putty`. [Code]
- `INDEX_SESSIONDIR` `:164–171`: `$PUTTYSESSIONS` oder `<DIR>/sessions`. [Code]
- `INDEX_HOSTKEYS` `:181–188`: `$PUTTYSSHHOSTKEYS` oder `<DIR>/sshhostkeys`; Tmp-Datei `:190–194`: `<sshhostkeys>.tmp`. [Code]

### 1.2 Sitzungsdatei lesen

`unix/storage.c:374–411` (`open_settings_r`)

```c
    fp = fopen(filename, "r");                    /* :383 */
    if (!fp) return NULL;                         /* :385-386 */
    while ( (line = fgetline(fp)) ) {             /* :391 */
        char *value = strchr(line, '=');          /* :392 */
        if (!value) { sfree(line); continue; }    /* :394-397 */
        *value++ = '\0';
        value[strcspn(value, "\r\n")] = '\0';     /* trim trailing NL */
        ...
        add234(toret->t, kv);                     /* ca. :404 */
```

- **Aufteilung am ersten `=`** (`strchr`). Schlüssel = alles davor, Wert = alles danach (Wert darf weitere `=` enthalten). [Code]
- **Zeilen ohne `=`** werden still übersprungen. [Code]
- **Kein Trimmen von Leerzeichen**, weder am Schlüssel noch am Wert; Schlüsselvergleich `strcmp`, also **groß/klein-sensitiv** (`keycmp` `:316–321`). [Code]
- **Zeilenende:** Wert wird am ersten `\r` **oder** `\n` abgeschnitten → `\n` und `\r\n` funktionieren beide. Ein `\r` mitten im Wert schneidet ab. Am Schlüssel wird nichts entfernt. [Code]
- **Doppelte Schlüssel: der erste gewinnt.** `add234` liefert bei Gleichheit das vorhandene Element zurück und fügt nicht ein (`tree234.h:51–54`: „Returns e on success, or if an existing element compares equal, returns that.“); `open_settings_r` ignoriert den Rückgabewert. [Code]
- **Maximale Zeilenlänge: keine.** `utils/fgetline.c:9–25` wächst in 512-Byte-Schritten (`sgrowarrayn_nm`), bis `\n` oder EOF. Letzte Zeile ohne `\n` wird trotzdem gelesen. [Code]
- Zahlen: `read_setting_i` `:433–449` → `atoi()` (kein Fehler bei Müll, ergibt 0). [Code]
- Fehlt ein Schlüssel, Fallback `get_setting` `:356–364` → `-o`-/X-Ressourcen (`provide_xrm_string`) → `x_get_default`, in plink immer `NULL` (`unix/plink.c:78–81`). [Code]

### 1.3 Sitzungsdatei schreiben

`unix/storage.c:235–291`

```c
    if ((err = make_dir_path(filename, 0700)) != NULL)   /* :243-244 DIR */
    if ((err = make_dir_path(filename, 0700)) != NULL)   /* :252-253 sessions */
    fp = fopen(filename, "w");                           /* :262 */
void write_setting_s(...) { fprintf(handle->fp, "%s=%s\n", key, value); }  /* :277-280 */
void write_setting_i(...) { fprintf(handle->fp, "%s=%d\n", key, value); }  /* :282-285 */
void close_settings_w(...) { fclose(handle->fp); sfree(handle); }          /* :287-291 */
```

- Format: eine Zeile `Schlüssel=Wert\n`, **kein Escaping** (ein Wert mit `\n` würde die Datei zerstören). [Code]
- **Nicht atomar:** direktes `fopen(..., "w")` auf die Zieldatei, keine tmp-Datei, kein `rename`, kein Fehlercheck bei `fclose`. [Code]
- Dateimodus: `fopen` → `0666 & ~umask` (typisch `0644`). Verzeichnisse: `mkdir(..., 0700)` → `0700 & ~umask` (`unix/utils/make_dir_path.c:14–39`, `EEXIST` wird toleriert, vorhandene Verzeichnisse werden **nicht** nachträglich `chmod`-iert). [Code]
- plink setzt **kein** `umask` (einziges `umask` im Unix-Code: `unix/x11.c:149–151`, nur für X11-Auth). Modus also abhängig von der umask des Elternprozesses (= unsere App). [Code]
- Löschen: `del_settings` `:538–544` → `unlink`. [Code]

### 1.4 `sshhostkeys`

Format-Kommentar `unix/storage.c:762–770`:

```
 *   type@port:hostname keydata
 *   rsa@22:foovax.example.org 0x23,0x293487364395345345....2343
```

Lesen `check_stored_host_key` `:771–842`:
- Pro Zeile wird nur `\n` entfernt (`line[strcspn(line, "\n")] = '\0';`, ca. `:794`) – **nicht `\r`**. Eine mit CRLF gespeicherte Datei führt beim Schlüsselvergleich (`strcmp(p, key)`) zu „Mismatch“ (Rückgabe 2) statt „unbekannt“. [Code] → App muss LF schreiben.
- Vergleich exakt mit `strncmp`: `keytype`, dann `@`, Port dezimal (`sprintf "%d"`), `:`, Hostname, ein Leerzeichen, Rest = Schlüsseldaten. Erste passende Zeile entscheidet (Schleife bricht bei `ret != 1` ab). Rückgabe 0 = passt, 1 = unbekannt (auch: Datei fehlt), 2 = abweichend. [Code]

Schreiben `store_host_key` `:853–922`:
- `fopen(<sshhostkeys>.tmp, "w")` `:864–865`; bei `ENOENT` `make_dir_path(DIR, 0700)` und neuer Versuch `:866–880`. [Code]
- Neue Zeile `dupprintf("%s@%d:%s %s\n", keytype, port, hostname, key)` (ca. `:890`). Alle alten Zeilen mit **gleichem Kopf bis einschließlich Leerzeichen** werden weggelassen, die übrigen kopiert, die neue ans Ende gehängt. [Code]
- `rename(tmp, sshhostkeys)` `:913` → **atomarer Austausch**; bei Fehler nur `seat_nonfatal`-Meldung „Unable to store host key: rename(…)“. `fclose(wfp)` ohne Fehlerprüfung. [Code]
- Modus: neue Datei per `fopen` → `0666 & ~umask`; durch `rename` gehen evtl. strengere Rechte der alten Datei verloren. [Code]
- Konkrete Typ-Kürzel (z. B. `ssh-ed25519`, `rsa2`, `ecdsa-sha2-nistp256`) stammen aus dem `cache_id` der Schlüsselalgorithmen. [offen – nicht in dieser Recherche geprüft]

Zum Vergleich: `randomseed` wird mit `open(..., O_CREAT|O_WRONLY, 0600)` angelegt (`:952`, `:972`). [Code]

---

## 2. Schlüsselnamen in Sitzungsdateien (`conf.h`, `settings.c`)

Seit 0.8x sind die Schlüssel tabellengesteuert in `conf.h` (`SAVE_KEYWORD`), Laden in `settings.c:708 ff.` (`load_open_settings`).

| Bedeutung | Schlüssel | Typ / Standard | Quelle |
|---|---|---|---|
| Host | `HostName` | String, `""` | `conf.h:30–34` |
| Port | `PortNumber` | Int, LOAD_CUSTOM | `conf.h:35–39` |
| Protokoll | `Protocol` | String (Backend-`id`), custom | `conf.h:40–48`, `settings.c:617–625`, `:791–801` |
| Benutzer | `UserName` | STR_AMBI, `""` | `conf.h:451–455` (Keyword `:454`) |
| Benutzer aus Umgebung | `UserNameFromEnvironment` | Bool, false | `conf.h:456–460` (Keyword `:459`) |
| Terminaltyp | `TerminalType` | String, `"xterm"` | `conf.h:414–418` (Keyword `:417`) |
| Marker | `Present=1` | wird immer geschrieben | `settings.c:617` |

### 2.1 Protokollwerte und Standardports (`id` / `default_port` der Backends)

| `Protocol=` | Backend | Standardport | Quelle |
|---|---|---|---|
| `ssh` | SSH | 22 | `ssh/ssh.c:1304, 1309` |
| `ssh-connection` | Bare ssh-connection | **keiner** (Feld fehlt → 0) | `ssh/ssh.c:1330–1335` |
| `telnet` | Telnet | 23 | `otherbackends/telnet.c:1101, 1105` |
| `rlogin` | Rlogin | 513 | `otherbackends/rlogin.c:491, 495` |
| `supdup` | SUPDUP | `0137` (oktal = 95) | `otherbackends/supdup.c:974, 978` |
| `raw` | Raw | **0 = kein Standardport** | `otherbackends/raw.c:375, 379` |
| `serial` | Serial | keiner (Feld fehlt) | `unix/serial.c:586–589` |

plink enthält alle davon: `CMakeLists.txt:143` `be_list(plink Plink SSH SERIAL OTHERBACKENDS)`; Reihenfolge in `be_list.c` (ssh, serial, telnet, rlogin, supdup, raw, ssh-connection). [Code]

Laden des Protokolls `settings.c:791–801`:

```c
    prot = gpps_raw(sesskey, "Protocol", "default");
    conf_set_int(conf, CONF_protocol, default_protocol);
    conf_set_int(conf, CONF_port, default_port);
    {
        const struct BackendVtable *vt = backend_vt_from_name(prot);
        if (vt) {
            conf_set_int(conf, CONF_protocol, vt->protocol);
            gppi(sesskey, "PortNumber", default_port, conf, CONF_port);
        }
    }
```

- Unbekannter/fehlender `Protocol`-Wert → globales `default_protocol`/`default_port`, **`PortNumber` wird dann ignoriert**. [Code]
- Fehlt `PortNumber` bei bekanntem Protokoll, gilt **nicht** der Port des Protokolls, sondern das globale `default_port` (in plink: 22, bzw. der Port aus „Default Settings“ oder `PLINK_PROTOCOL`, `unix/plink.c:707–726`). Folge: Eine `raw`-Sitzung ohne `PortNumber` bekommt Port 22. → Die App sollte `PortNumber` immer schreiben. [Code]
- Schreiben: `Protocol` = `vt->id`, Fallback `"raw"` (`settings.c:618–625`). [Code]
- `backend_vt_from_name` `settings.c:97–104`: exakter `strcmp` auf die `id` (groß/klein-sensitiv). [Code]
- Kommandozeile `-raw`: `set_port` nur wenn `default_port != 0` (`cmdline.c` Backend-Schleife ca. `:436–452`) → `-raw` behält den bisherigen Port. [Code]

### 2.2 Besondere Behandlung von Werten

- Beim **Laden** keine Sonderbehandlung: `gpps` übernimmt den String unverändert (`settings.c:130–146`). [Code]
- Das Aufspalten passiert erst in **`prepare_session`** (`utils/sessprep.c:8–84`), das plink nach `cmdline_host_ok` und **vor** `cmdline_run_saved` aufruft (`unix/plink.c` ca. `:819`):
  - führende Leerzeichen/Tabs weg (`:17`);
  - `user@host`: **letztes** `@` (`strrchr`) trennt; der Teil davor **überschreibt** `UserName` aus der Sitzung (`:28–33`);
  - genau **ein** `:` → alles ab `:` wird **abgeschnitten und ignoriert** (kein Port!); bei mehreren `:` (IPv6 ohne Klammern) bleibt alles stehen (`:65–68`);
  - danach werden **alle** Leerzeichen/Tabs entfernt (`:73–80`). [Code]
  - Da `-l` gespeichert und erst in `cmdline_run_saved` angewendet wird, gewinnt `-l` gegen `user@` im HostName. [abgeleitet]
- `conf_launchable` (`utils/conf_launchable.c:8–14`): startbar = `HostName` nicht leer (bei serial: `SerialLine` nicht leer). [Code]
- Terminaltyp: `platform_default_s` in plink prüft noch den alten Namen `"TermType"` (`unix/plink.c:45–53`), der Schlüssel heißt aber `TerminalType` → der `$TERM`-Fallback greift beim Laden nicht; ohne Eintrag gilt `"xterm"`. [Code; Auswirkung im Test bestätigen]
- `UserName` ist `STR_AMBI` (kann als UTF-8 markiert sein); beim Laden aus Datei normaler String. [Code]

---

## 3. `plink -load <name>` (`unix/plink.c`, `cmdline.c`)

Ablauf in `main` (`unix/plink.c:690 ff.`):

1. Startwerte `settings_set_default_protocol(PROT_SSH)` / `settings_set_default_port(22)` (ca. `:702–703`).
2. **„Default Settings“ wird immer zuerst geladen:** `do_defaults(NULL, conf);` `:710` (NULL → „Default Settings“, s. 1.1); danach werden `default_protocol`/`default_port` aus diesem Ergebnis gesetzt (`:711–712`). `PLINK_PROTOCOL` kann beides überschreiben (`:715–726`). [Code]
3. Argumentschleife über `cmdline_process_param` (ab ca. `:727`).

`-load` in `cmdline.c:428–435`:

```c
    if (!strcmp(p, "-load")) {
        RETURN(2);
        /* This parameter must be processed immediately rather than being
         * saved. */
        do_defaults(value, conf);
        loaded_session = true;
        return 2;
    }
```

- `-load` wird **sofort** ausgeführt (nicht gespeichert), Kommentar `cmdline.c:25–28`. [Code]
- **Kein Überlagern:** `do_defaults` → `load_settings` (`settings.c:693–706`, `:1054–1057`) setzt **jeden** Conf-Schlüssel neu – aus der Datei oder aus dem **eingebauten** Standard. Werte aus „Default Settings“ gehen also verloren; nur `default_protocol`/`default_port` (aus Schritt 2) wirken als Fallback für `Protocol`/`PortNumber`. [Code]
- **Sitzung existiert nicht:** Rückgabewert von `do_defaults` wird ignoriert → **still eingebaute Standardwerte**, `loaded_session = true`, keine Meldung. Folge ohne weiteren Host: `HostName` leer → `cmdline_host_ok` falsch → `plink: no valid host name provided` / `try "plink --help" for help`, Exit 1 (`unix/plink.c` ca. `:812–816`). [Code]
- **Host aus der Sitzung:** Ist die geladene Sitzung startbar (`HostName` gesetzt), reicht `plink -load name` (`cmdline_host_ok` `cmdline.c:974–1004`: launchable **und** `loaded_session`). [Code]
- **Argument nach `-load`:** plink hat `TOOLTYPE_HOST_ARG_FROM_LAUNCHABLE_LOAD` (`unix/plink.c:595–599`). Ein Nicht-Options-Argument wird nur dann als Host genommen, wenn die geladene Sitzung **nicht** startbar ist (`cmdline.c` Host-Zweig, Bedingung ca. `:211–214`). Bei startbarer Sitzung gibt `cmdline_process_param` 0 zurück (plink hat kein `TOOLTYPE_PORT_ARG`), und plink behandelt **dieses und alle folgenden Argumente als Remote-Befehl** (`unix/plink.c:787–802`: `remote_cmd`, `nopty = true`, Schleifenende). [Code]
- `-load` ohne Wert → `plink: option "-load" requires an argument`, Exit 1 (`RETURN(2)` → −2, `unix/plink.c` ca. `:733–736`, `:809–810`). Der Wert darf mit `-` beginnen (wird blind als nächstes Argument genommen). [Code]
- Ein bloßes Host-Argument (ohne `-load`) wird ebenfalls als Sitzungsname probiert (`TOOLTYPE_HOST_ARG_CAN_BE_SESSION`, `cmdline.c:383`), nur wenn startbar übernommen. → Die App sollte immer `-load` benutzen, nie den Namen als Host. [Code]

### 3.1 `--` als Optionsende

**Gibt es in plink nicht.** Kein `"--"` in `cmdline.c` oder `unix/plink.c` (einziger Treffer im Unix-Code: `unix/pageant.c:1439`). `--` würde als `plink: unknown option "--"` gemeldet (`unix/plink.c` ca. `:803–805`) → Exit 1. Optionen werden nur bis zum ersten Nicht-Options-Argument (= Host bzw. Befehl) ausgewertet. [Code]

### 3.2 Optionen, die mit `-load` kollidieren können

Gespeicherte Optionen (`SAVEABLE`) werden **nach** `-load` und nach `prepare_session` in `cmdline_run_saved` angewendet (`cmdline.c` ca. `:963–971`), **unabhängig von der Reihenfolge** auf der Kommandozeile – sie überschreiben also immer die Sitzung:

- Protokoll: `-ssh -telnet -rlogin -supdup -raw -serial -ssh-connection` (Schleife über `backends[]`, setzt auch Port), `-P`, `-l`, `-pw`, `-pwfile`, `-i`, `-cert`, `-hostkey`, `-A/-a`, `-X/-x`, `-t/-T`, `-N`, `-nc`, `-C`, `-1/-2`, `-4/-6` (`-ipv4/-ipv6`), `-L/-R/-D`, `-m`, `-proxycmd`, `-loghost`, `-preconnectcommand`, `-share/-noshare`, `-pagent/-nopagent`, `-no-trivial-auth`, `-sessionlog/-sshlog/-sshrawlog/-logoverwrite/-logappend`, `-sercfg`, `-batch`. (Liste der `strcmp(p, "…")` in `cmdline.c:428–955`.) [Code]
- **Ein zweites `-load`** lädt sofort neu und überschreibt alles vorher Geladene. [Code]
- plink-eigene Optionen (`unix/plink.c:745–786`): `-s`, `-V/--version`, `--help`, `-pgpfp`, `-o` (X-Ressource → wirkt als Fallback **unter** fehlenden Sitzungsschlüsseln, `storage.c:356–364`), `-shareexists`, `-fuzznet`, `-(no-)sanitise-stdout/-stderr`, `-no-antispoof`. [Code]
- Umgebungsvariablen, die die Sitzungsablage verbiegen: `PUTTYDIR`, `PUTTYSESSIONS`, `PUTTYSSHHOSTKEYS`, `PUTTYRANDOMSEED`, `PUTTYSSHHOSTCAS`, `XDG_CONFIG_HOME`, `HOME`; Protokoll: `PLINK_PROTOCOL`. → Die App sollte diese beim Start von plink gezielt setzen/entfernen. [Code]

---

## 4. Anti-Spoofing („Access granted. Press Return to begin session.“)

Erzeugung `ssh/connection2.c:1006–1023` (SSH-1 analog `ssh/connection1.c:375–391`):

```c
    if (ssh2_connection_need_antispoof_prompt(s)) {
        ...
        s->antispoof_prompt->name = dupstr("Authentication successful");
        add_prompt(s->antispoof_prompt,
            dupstr("Access granted. Press Return to begin session. "), false);
        s->antispoof_ret = seat_get_userpass_input(...);
```

Bedingung `ssh/connection2-client.c:501–511`:

```c
    seat_set_trust_status(s->ppl.seat, false);
    if (!seat_has_mixed_input_stream(s->ppl.seat)) return false;
    if (seat_can_set_trust_status(s->ppl.seat))   return false;
    if (ssh_is_bare(s->ppl.ssh))                  return false;
    return true;
```

plink-Seat (`unix/console.c`):
- `console_can_set_trust_status` `:365–376`: `true` nur im **Batch-Modus** (`-batch`), sonst `false`.
- `console_has_mixed_input_stream` `:379–394`: `false`, wenn `!is_interactive()` (**stdin ist kein TTY**, `isatty(0)`) **oder** `-no-antispoof` (`console_antispoof_prompt = false`, `unix/plink.c:785–786`, Variable `unix/console.c:355`).

**Ergebnis – die Abfrage erscheint genau dann, wenn:** SSH (nicht `ssh-connection`/Sharing-Downstream) **und** stdin ein TTY **und** kein `-batch` **und** kein `-no-antispoof`. [Code]

- **Unabhängig davon, ob vorher eine Passwort-/KI-Abfrage stand.** Die Bedingung prüft keinerlei Authentifizierungsart; sie erscheint also **auch bei reiner Schlüssel-/Agent-Anmeldung** ohne jede Eingabe. Der Kommentar `connection2.c:997–1004` sagt ausdrücklich, dass es bewusst nach der Userauth-Phase und unabhängig von ihr geschieht. [Code]
- Das Ergebnis `antispoof_ret` wird **nicht ausgewertet** (keine Abfrage auf Abbruch) – auch EOF/Lesefehler lässt die Sitzung weiterlaufen. [Code]
- Getrennt davon: Banner und keyboard-interactive-Abfragen werden mit Kopf-/Fußzeilen eingerahmt (`seat_antispoof_msg`, `utils/antispoof.c:4–28`, Aufrufe `ssh/userauth2-client.c` ca. `:1747`, `:2076`, `:2098`, `:2170`). Ohne Trust-Anzeige als `-- <Text> ----…` auf 78 Zeichen aufgefüllt. „Access granted“ in `userauth2-client.c:850` ist nur ein Event-Log-Eintrag. [Code]

**Was beendet das Warten:** Die Abfrage läuft über `plink_get_userpass_input` (`unix/plink.c` ca. `:383–394`) → `console_get_userpass_input` (s. 5.2), Echo aus:
- Eingabe kommt von **`/dev/tty`**, falls öffnbar, sonst fd 0 (`console_open`, `unix/console.c` ca. `:458–469`).
- Terminal wird auf `ICANON | ISIG` gesetzt (kanonischer Modus); die Schleife endet erst, wenn das gelesene Stück auf **`\n`** endet (`strbuf_chomp(pr->result, '\n')`, `utils/strbuf.c:47–54`).
- **CR** funktioniert nur über die TTY-Übersetzung `ICRNL` (wird von der Funktion nicht verändert, ist im Normalfall aktiv; plink setzt `ICRNL` in `plink_echoedit_update` bei `edit`, `unix/plink.c` ca. `:96–98`). Über ein PTY ist daher **`\r` (Return) oder `\n`** in Ordnung; in einen Pipe-stdin geschriebenes `\r` würde **nicht** beenden – dort tritt die Abfrage aber ohnehin nicht auf. [Code / abgeleitet]
- Für die App (PTY als stdin): Abfrage erscheint → entweder `-no-antispoof` übergeben oder nach Erkennen der Zeile `\r` senden. [abgeleitet]

---

## 5. `unix/console.c` – Hostschlüssel- und Passwortabfrage

### 5.1 Hostschlüssel (`console_confirm_ssh_host_key`, `unix/console.c:151–217`, Zeilen innen ca.)

- Text: Absätze aus `SeatDialogText` (gedruckt in `console_print_seatdialogtext` `:105–149`, Umbruch bei 60 Zeichen). Eingabezeile:
  `"%s (y/n, Return cancels connection, i for more info) "` (ca. `:168–170`), wobei `%s` der `SDT_PROMPT`-Text ist. Ausgabe auf **stderr**. Den genauen Wortlaut der Absätze/des Prompts (erzeugt im gemeinsamen SSH-Code) habe ich hier **nicht** nachgelesen. [offen]
- Batch-Modus: `SDT_BATCH_ABORT` → `SPR_SW_ABORT("Cannot confirm a host key in batch mode")` (ca. `:161–165`). [Code]
- Lesen: **von fd 0 (stdin), nicht `/dev/tty`**; fd 0 auf `ECHO | ISIG | ICANON`, **ein** `block_and_read(0, line, 31)` (ca. `:173–181`). Nur das **erste Zeichen** zählt. [Code]
- Auswertung (ca. `:207–217`):

```c
    if (line[0] != '\0' && line[0] != '\r' && line[0] != '\n' &&
        line[0] != 'q' && line[0] != 'Q') {
        if (line[0] == 'y' || line[0] == 'Y')
            store_host_key(seat, host, port, keytype, keystr);
        return SPR_OK;
    } else {
        fputs(console_abandoned_msg, stderr);   /* "Connection abandoned.\n" */
        return SPR_USER_ABORT;
    }
```

| Eingabe (1. Zeichen) | Wirkung |
|---|---|
| `y`/`Y` | speichern + verbinden |
| `n`/`N` **oder jedes andere** Zeichen außer den folgenden | einmalig verbinden, nicht speichern |
| `i`/`I` | Zusatzinfos (Fingerprints) zeigen, erneut fragen (Schleife ca. `:183–203`) |
| Return (`\r`/`\n`), `q`/`Q` | „Connection abandoned.“, Abbruch |
| **EOF (Ctrl-D, read = 0) oder Lesefehler (< 0)** | `line[0]` bleibt `'\0'` → **wie Return: Abbruch** |

`console_abandoned_msg` = `"Connection abandoned.\n"` (`console.c:12`). Antwortbeschreibung für die Texte: `console.c:14–25` (`hk_accept_action = "enter \"y\""`, `hk_connect_once_action = "enter \"n\""`, `hk_cancel_action = "press Return"`). [Code]

Achtung: Weil nur ein `read` erfolgt, muss die Antwort **in einem Stück** inkl. Zeilenende gesendet werden (bei TTY im kanonischen Modus liefert `read` ohnehin die ganze Zeile). [Code/abgeleitet]

### 5.2 Passwort/Prompts (`console_get_userpass_input`, `unix/console.c` ca. `:482–580`)

- Batch-Modus mit Prompts → `SPR_SW_ABORT("Cannot answer interactive prompts in batch mode")`. [Code]
- Ein-/Ausgabe über **`/dev/tty`** (falls vorhanden), sonst stdin/stderr (`console_open`). [Code]
- TTY: `ISIG | ICANON`, `ECHO` aus bei Passwörtern; Lesen in Blöcken bis das Ergebnis auf `\n` endet (`strbuf_chomp`); ein vorangehendes `\r` bliebe im Passwort, wenn kein `ICRNL` aktiv ist. [Code]
- **EOF (`read == 0`) → `SPR_USER_ABORT`** („Regard EOF on the terminal as a deliberate user-abort“). **Lesefehler (`< 0`) → `SPR_SW_ABORT` „Error reading from terminal“ + errno.** [Code]
- Vorher: `cmdline_get_passwd_input` (`cmdline.c:84 ff.`) beantwortet genau **einen** nicht-echoenden Server-Prompt mit `-pw`/`-pwfile`; zweiter Versuch → `SPR_SW_ABORT("Configured password was not accepted")`. [Code]

---

## 6. Exit-Codes von plink

| Situation | Exit | Quelle |
|---|---|---|
| Normales Ende, Server meldet `exit-status` | **Exit-Status des Remote-Prozesses** | `ssh/ssh.c:1240–1243` (`ssh_got_exitcode`), `:1245–1252`; `unix/plink.c` ca. `:984–989` |
| Ende ohne gemeldeten Status (z. B. `exit-signal`) | `ssh_return_exitcode` liefert `INT_MAX` → `exit(INT_MAX)` → unter macOS/POSIX Status **255** (nur niederwertiges Byte) | `ssh/ssh.c:1251` [abgeleitet; ob `exit-signal` selbst einen Code setzt: offen] |
| Backend meldet noch „läuft/unklar“ (−1) | „Remote process exit code unavailable“, **1** | `unix/plink.c` ca. `:985–988` |
| Verbindungsaufbau scheitert sofort (DNS, Adressfehler) | „Unable to open connection:\n…“, **1** | `unix/plink.c` ca. `:958–967` |
| Spätere Netz-/Protokoll-/Software-Fehler (refused, Timeout, Auth-Methoden erschöpft, Batch-Abbruch, `-pw` falsch) | `seat_connection_fatal` → „FATAL ERROR: …“ → `cleanup_exit(1)` → **1** (die intern gesetzten 128 kommen nicht an) | `ssh/ssh.c:472–557`, `console.c:72–76` |
| **Nutzerabbruch** (Hostschlüssel: Return/q/EOF; EOF in Passwort-/Benutzerabfrage) | `ssh_spr_close` → `ssh_user_close` → `exitcode = 0` → **0** („Connection abandoned.“ auf stderr) | `ssh/common.c:1267–1277`, `ssh/ssh.c:559–585` (Kommentar: „does count as a clean exit“) [abgeleitet, im Test bestätigen] |
| Optionsfehler / kein Host / unbekannte Option / `--` | **1** | `unix/plink.c` ca. `:733–736`, `:803–816` |
| `--help`, `-pgpfp` | 0 | `unix/plink.c` ca. `:751–757` |
| stdin-Lesefehler, `pipe()`-Fehler | `exit(1)` | `unix/plink.c` (stdin: `perror("stdin: read")`), ca. `:873–876` |

**Konsequenz für M1:** Nutzerabbruch und erfolgreiches Ende sind am Exit-Code **nicht** unterscheidbar (beide 0). Die App muss stderr („Connection abandoned.“, „FATAL ERROR:“) bzw. ihren eigenen Zustand (Abbruch selbst ausgelöst?) auswerten. [abgeleitet]

---

## Offene Punkte für den M1-Test

1. Genauer Wortlaut des Hostschlüssel-Prompts (`SDT_PROMPT`) und Typ-Kürzel in `sshhostkeys`.
2. Exit-Code bei `exit-signal` (Server beendet Prozess per Signal).
3. Praxistest: Nutzerabbruch bei Hostschlüssel → wirklich Exit 0?
4. Praxistest: Antispoof-Abfrage bei reiner Schlüssel-Anmeldung über PTY; Beenden mit `\r`.
5. Praxistest: `raw`-Sitzung ohne `PortNumber` → Port 22.
