# M7 – Recherche (API-Fakten)

Stand: 20.10.2026 · Projekt: TunnelTerminal (Swift 6, AppKit + SwiftUI, macOS 14+, Apple Silicon, ohne App Sandbox, Hardened Runtime, ad-hoc signiert, Xcode 27, plink als Hilfsprogramm)

Kennzeichnung im Text:
- **[Beleg]**: Aussage steht so in der verlinkten Primärquelle.
- **[Schluss]**: eigene Folgerung aus belegten Fakten, nicht wörtlich belegt.
- **[nicht belegt]**: Keine Primärquelle gefunden. Vor Verwendung selbst testen.

Hinweis zur Quellenlage: Apple-Doku wurde über die Markdown-Fassung der Seiten gelesen (`….md`). Die PuTTY-Website (chiark.greenend.org.uk) ließ sich nur teilweise abrufen: Viele Seiten waren für das Abrufwerkzeug per robots.txt gesperrt, manche kamen offenbar aus einem veralteten Cache. Ergänzend wurde der Spiegel `ftp.cvut.cz/putty/` gelesen, der auf die Primärseite verweist. Ob dieser Spiegel offiziell gelistet ist, ließ sich nicht prüfen, weil die abrufbare `mirrors.html` veraltet war (Stand 2017).

---

## 1. URL-Schemata `ssh://` und `telnet://` empfangen

### 1a) Info.plist `CFBundleURLTypes`

**Befunde**
- `CFBundleURLTypes` ist „A list of URL schemes (http, ftp, and so on) supported by the app“ (macOS 10.0+). Die Unterschlüssel sind `CFBundleTypeRole`, `CFBundleURLIconFile`, `CFBundleURLName` und `CFBundleURLSchemes` [Beleg] ([Apple: CFBundleURLTypes](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes)).
- Die heutige Doku-Seite zu `CFBundleTypeRole` nennt keine zulässigen Werte ([Apple: CFBundleTypeRole](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes/cfbundletyperole)). Nur die archivierte Information Property List Key Reference sagt: „The value can be `Editor`, `Viewer`, `Shell`, or `None`. This key is required.“ [Beleg] Dort steht auch „Viewer. The app can read and present data of that type.“ [Beleg] Für `CFBundleURLName` wird ein Bezeichner im Java-Paket-Stil empfohlen [Beleg] ([Apple Archiv: Core Foundation Keys, Tabelle 7](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)).
- Rolle **Viewer** passt für einen Terminal-Client, der Verbindungen nur öffnet und darstellt [Schluss].

**Folgen für die App**
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>    <string>$(PRODUCT_BUNDLE_IDENTIFIER).remote-login</string>
    <key>CFBundleTypeRole</key>   <string>Viewer</string>
    <key>CFBundleURLSchemes</key> <array><string>ssh</string><string>telnet</string></array>
  </dict>
</array>
```

### 1b) `NSApplicationDelegate.application(_:open:)`: Verfügbarkeit und Reihenfolge beim Kaltstart

**Befunde**
- Die Methode ist ab macOS 10.13 verfügbar und lautet `@MainActor optional func application(_ application: NSApplication, open urls: [URL])` [Beleg]. AppKit ruft sie auf, „when your app is asked to open one or more URL-based resources“. Die Schemata müssen unter `CFBundleURLTypes` deklariert sein [Beleg]. Ist die Methode implementiert, ruft AppKit `application(_:openFile:)` und `application(_:openFiles:)` nicht mehr auf [Beleg] ([Apple: application(_:open:)](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))). Die AppKit-Release-Notes zu 10.13 sagen dasselbe: „This will be called for any URLs your application is asked to open, including URL types …“ [Beleg] ([AppKit Release Notes](https://developer.apple.com/library/archive/releasenotes/AppKit/RN-AppKit/index.html)).
- **Reihenfolge, soweit dokumentiert:** Belegt ist sie nur für **Dateien**. In der Doku heißt es: „If the application was launched by the user opening a file, the delegate’s `application(_:openFile:)` method is called before this method [= applicationDidFinishLaunching]“ und `applicationWillFinishLaunching(_:)` „is called before `application(_:openFile:)`“ [Beleg] ([Apple: applicationDidFinishLaunching(_:)](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationdidfinishlaunching(_:))). Laut Cocoa Scripting Guide wird `applicationDidFinishLaunching:` bei den Standard-Apple-Events (open application, open documents, print …) **nach** deren Behandlung aufgerufen. Die einzige Ausnahme ist „open contents“ [Beleg] ([Apple Archiv: How Cocoa Applications Handle Apple Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/SApps_handle_AEs/SAppsHandleAEs.html)).
- **Für URLs (Apple Event „get URL“) und `application(_:open:)` ist die Reihenfolge nicht dokumentiert** [nicht belegt]. Ein Entwickler hat im Juli 2024 im Apple-Developer-Forum genau danach gefragt und keine Antwort erhalten ([Apple Forum 760912](https://developer.apple.com/forums/thread/760912)).
- Ein eigener „get URL“-Handler über `NSAppleEventManager` sollte in `applicationWillFinishLaunching:` installiert werden. Er ersetzt dann den Handler von AppKit („If an event handler is already installed … it is replaced“) [Beleg] (Cocoa Scripting Guide, s. o.). Mit eigenem Handler würde `application(_:open:)` für URLs vermutlich nicht mehr aufgerufen [Schluss].
- `NSApplication.launchIsDefaultUserInfoKey` (macOS 10.7+) in der userInfo von `didFinishLaunching` ist `false`, „if the app was launched to open or print a file, to perform a Service action, if the app had saved state … or … not a default launch“ [Beleg] ([Apple: launchIsDefaultUserInfoKey](https://developer.apple.com/documentation/appkit/nsapplication/launchisdefaultuserinfokey)). Ob ein URL-Start ausdrücklich darunter fällt, steht dort nicht [nicht belegt].

**Folgen für die App**
- Den Zustand (Session-Manager, Warteschlange für eingehende URLs) schon in `applicationWillFinishLaunching` anlegen. `application(_:open:)` schiebt URLs nur in die Warteschlange. Abgearbeitet wird erst, wenn die UI bereit ist, also nach `applicationDidFinishLaunching`. Beide Reihenfolgen müssen funktionieren [Schluss].
- Kein leeres Startfenster öffnen, wenn beim Start URLs anstehen (Warteschlange prüfen und zusätzlich `launchIsDefaultUserInfoKey` auswerten).
- Läuft die App schon (Warmstart), wird derselbe Weg benutzt. Keinen zusätzlichen `NSAppleEventManager`-Handler installieren.

### 1c) `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)`

**Befunde**
- Verfügbar ab **macOS 12.0**. Es gibt zwei Formen [Beleg]:
  `func setDefaultApplication(at applicationURL: URL, toOpenURLsWithScheme urlScheme: String, completion completionHandler: (@Sendable ((any Error)?) -> Void)? = nil)`
  `func setDefaultApplication(at applicationURL: URL, toOpenURLsWithScheme urlScheme: String) async throws`
  ([Apple: setDefaultApplication(at:toOpenURLsWithScheme:completion:)](https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:)))
- **Bestätigungsdialog: ja, möglich.** Die Doku sagt: „If a change requires user consent, the system asks the for consent asynchronously before invoking the completion handler.“ [Beleg] (ebd.). Die Datei-Variante formuliert es genauso ([Apple: setDefaultApplication(at:toOpenFileAt:completion:)](https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenfileat:completion:))). **Wann** eine Zustimmung nötig ist, etwa für `ssh` oder `telnet`, dokumentiert Apple nicht [nicht belegt].
- Fehlerfälle: In der Doku stehen keine. Apple-DTS (Quinn) schreibt im Forum: Aus einer **sandboxed** App schlägt der Aufruf mit einem allgemeinen Fehler fehl, darunter liegt `-54 (permErr)`. Außerdem sei `LSSetDefaultHandlerForURLScheme` „deprecated in favour of NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)“ ([Apple Forum 800777](https://developer.apple.com/forums/thread/800777); vgl. [Apple Forum 769441](https://developer.apple.com/forums/thread/769441)). TunnelTerminal ist nicht sandboxed, der permErr-Fall betrifft die App also nicht [Schluss]. Was passiert, wenn der Nutzer ablehnt (Fehler? welcher Code?), ist nicht dokumentiert [nicht belegt]. Auf welchem Thread der Completion-Handler läuft, ist ebenfalls nicht dokumentiert [nicht belegt]. Die Signatur ist `@Sendable`.

**Folgen für die App**
- Nur auf ausdrückliche Nutzeraktion aufrufen, z. B. über einen Knopf „Als Standard für ssh/telnet festlegen“ in den Einstellungen. Je Schema ein eigener Aufruf. Die async-Variante nehmen und das Ergebnis auf dem MainActor anzeigen.
- Danach immer mit `urlForApplication(toOpen:)` (1d) prüfen, ob die Änderung wirklich gegriffen hat. So bleiben ein abgelehnter Dialog und unbekannte Fehler beherrschbar [Schluss].

### 1d) Aktuelle Standard-App ermitteln

**Befunde**
- `func urlForApplication(toOpen url: URL) -> URL?` (macOS 10.6+) „Returns the URL to the default app to open the specified URL“ und liefert `nil`, „if no app can open the URL“. Die Methode darf von jedem Thread aufgerufen werden [Beleg] ([Apple: urlForApplication(toOpen:)](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(toopen:)-7qkzf)).
- `urlsForApplications(toOpen:)` (macOS 12+) liefert alle Apps, die die URL öffnen können, „The returned array lists the best match first“ [Beleg] ([Apple: urlsForApplications(toOpen:)](https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications(toopen:)-ualk)).

**Folgen für die App**
- Abfrage mit einer Platzhalter-URL je Schema, z. B. `URL(string: "ssh://localhost")!`. Verglichen wird über die Bundle-ID der gefundenen App (`Bundle(url:)?.bundleIdentifier`) statt über Pfade, weil Kopien in DerivedData und in /Applications nebeneinander liegen können [Schluss].

### 1e) Safari und fremde Schemata

- Für die Rückfrage „Möchtest du zulassen, dass diese Seite … öffnet?“ habe ich **keine Primärquelle** gefunden, weder in der Apple-Entwicklerdoku noch im Safari- oder Kurzbefehle-Benutzerhandbuch [nicht belegt]. Zum Beispiel enthält [Intro to URL schemes in Shortcuts on Mac](https://support.apple.com/guide/shortcuts-mac/apd621a1ad7a/mac) dazu nichts.
- **Folge [Schluss]:** Jede eingehende URL kann von einer Webseite ausgelöst sein. Deshalb startet die App plink nie automatisch. Sie zeigt immer zuerst einen Bestätigungsdialog mit Host, Benutzer und Port, Standard-Knopf „Abbrechen“.

---

## 2. Formate: SSH-URI, Telnet-URI, RFC 3986, IPv6-Zonen

### SSH-URI (draft-ietf-secsh-scp-sftp-ssh-uri-04)
- Status: Internet-Draft vom 1. Februar 2006, abgelaufen am 5. August 2006, kein RFC geworden („Expired & archived“) [Beleg] ([Datatracker](https://datatracker.ietf.org/doc/html/draft-ietf-secsh-scp-sftp-ssh-uri-04)). Bei der IANA ist das Schema `ssh` als **provisional** registriert, Referenz ist dieser Draft [Beleg] ([IANA: ssh](https://www.iana.org/assignments/uri-schemes/prov/ssh)).
- Grammatik (Abschnitt 3.3) [Beleg] ([Draft-Text](https://www.ietf.org/archive/id/draft-ietf-secsh-scp-sftp-ssh-uri-04.txt)):
  ```
  sshURI     =  "ssh:" hier-part
  hier-part  =  "//" authority path-abempty
  authority  =  [ [ ssh-info ] "@" ] host [ ":" port ]
  ssh-info   =  [ userinfo ] [";" c-param *("," c-param)]
  c-param    =  paramname "=" paramvalue
  paramname  =  *( ALPHA / DIGIT / "-" )
  paramvalue =  *( ALPHA / DIGIT / "-" )
  ```
  Die Zeichen „;“, „,“, „:“ und „=“ dienen als Trennzeichen. „They must not be escaped when used as delimiters and must be escaped when the appear in other uses.“ [Beleg]
- **conn-params:** Definiert ist nur `fingerprint`, kodiert als `host-key-alg-fingerprint`, mit „a single dash "-" as a separator instead of the colon“. „There MUST be only one fingerprint parameter“. Beispiel: `ssh://user;fingerprint=ssh-dss-c1-b1-30-29-d7-b8-de-6c-97-77-10-d7-46-41-63-87@host.example.com`. Unbekannte Parameter „SHOULD be ignored“ [Beleg] (Abschnitte 3.4, 5.1, 6).
- Semantik: Fehlt der Port, gilt der Standardport. Ein nicht leerer Pfad „SHOULD be ignored“. Ein Passwort nach „:“ ist „NOT RECOMMENDED and is deprecated“ [Beleg] (Abschnitt 3.4).
- Sicherheit: „This parameter MUST NOT overwrite a key that is already configured for the host.“ Der Fingerprint „MAY be used to validate … if the URL was obtained from an authenticated source with its integrity protected“. Allgemein „should have no more trust associated with it than a raw public key received in the SSH protocol itself“ [Beleg] (Abschnitte 5.1, 8).
- [Schluss] Nach der Grammatik darf `paramvalue` nur ALPHA, DIGIT und „-“ enthalten. Ein moderner `SHA256:…`-Fingerprint in Base64 enthält aber „+“, „/“ und „=“ und passt deshalb nicht hinein. Belegt ist nur das alte Hex-Format.

### Telnet-URI (RFC 4248, Oktober 2005, Standards Track)
- Form `telnet://<user>:<password>@<host>:<port>/`. „The final "/" character may be omitted.“ „If :<port> is omitted, the port defaults to 23.“ Der Teil `:<password>` und auch der ganze Teil `<user>:<password>` können entfallen. Benutzer und Passwort „are advisory only“ [Beleg] ([RFC 4248](https://www.rfc-editor.org/rfc/rfc4248.txt)).
- Sicherheit: Telnet nutzt „passwords in the clear“, Identität und Passwort sind „exposed without any protection“ [Beleg] (ebd., Abschnitt 3).

### RFC 3986 (userinfo, host, Prozent-Kodierung)
- Grammatik [Beleg] ([RFC 3986](https://www.rfc-editor.org/rfc/rfc3986.txt)):
  ```
  authority   = [ userinfo "@" ] host [ ":" port ]
  userinfo    = *( unreserved / pct-encoded / sub-delims / ":" )
  host        = IP-literal / IPv4address / reg-name
  IP-literal  = "[" ( IPv6address / IPvFuture  ) "]"
  reg-name    = *( unreserved / pct-encoded / sub-delims )
  pct-encoded = "%" HEXDIG HEXDIG
  sub-delims  = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
  ```
- §3.2.1: „Use of the format "user:password" in the userinfo field is deprecated.“ Anwendungen sollen Daten nach dem ersten „:“ nicht im Klartext anzeigen und „should reject the storage of such data in unencrypted form“ [Beleg].
- §3.2.2: „The host subcomponent is case-insensitive.“ Ein IP-Literal steht in eckigen Klammern, und das ist „the only place where square bracket characters are allowed“. Nicht-ASCII-Zeichen im reg-name werden nach UTF-8 kodiert, jedes Oktett prozent-kodiert [Beleg].
- §2.1: Groß- und Kleinbuchstaben A–F gelten in Prozent-Kodierungen als gleich. §2.4: Komponenten „must be parsed and separated before the percent-encoded octets … can be safely decoded“ [Beleg].

### IPv6-Zone-ID (RFC 6874 → RFC 9844)
- RFC 6874 (Februar 2013) hatte `IP-literal = "[" ( IPv6address / IPv6addrz / IPvFuture ) "]"`, `IPv6addrz = IPv6address "%25" ZoneID` eingeführt, Beispiel `http://[fe80::a%25en1]`, und „ZoneID is of local significance only“ [Beleg] ([RFC 6874](https://www.rfc-editor.org/rfc/rfc6874.txt)).
- **RFC 6874 ist durch RFC 9844 (August 2025) obsolet.** RFC 9844 „reverts the change that it made to the URI syntax defined by RFC 3986“ [Beleg] ([RFC-Editor-Info 6874](https://www.rfc-editor.org/info/rfc6874), [RFC 9844](https://www.rfc-editor.org/rfc/rfc9844.html)). Für Benutzeroberflächen empfiehlt RFC 9844 die Eingabe im Format nach RFC 4007, z. B. `fe80::1%eth0`, oder ersatzweise mit „-“ als Trennzeichen. Ungültige Zone-IDs soll die UI als Fehler melden [Beleg].

**Folgen für die App**
- [Schluss] Erst die Komponenten trennen, dann dekodieren. `userinfo` am ersten „;“ teilen (Benutzer | conn-params), denn „;“, „,“ und „=“ sind laut RFC 3986 in userinfo erlaubt. Eine Standard-URL-Zerlegung liefert sie deshalb im Benutzerteil mit.
- Passwörter aus URLs nie anzeigen, nie speichern und nie an plink übergeben. Höchstens den Hinweis zeigen: „URL enthielt ein Passwort, es wurde ignoriert“.
- Den Fingerprint aus der URL nur als **Vergleichswert** anzeigen. Nie automatisch vertrauen und nie einen vorhandenen Host-Key überschreiben.
- `%25`-Zonen in URLs gelten seit RFC 9844 nicht mehr als Standard. Das Verhalten nachsichtig oder strikt festlegen und mit `URLComponents` testen [nicht belegt]. Für manuelle Eingabe `fe80::1%en0` akzeptieren.
- [Schluss] Host- und Benutzerwerte vor der Übergabe an plink prüfen: kein führendes „-“, keine Steuerzeichen. `Process` immer mit Argument-Array starten, ohne Shell.

---

## 3. Release-Bau ohne `get-task-allow` und ohne persönliche Pfade

### 3a) `get-task-allow` bei „Sign to Run Locally“ (`CODE_SIGN_IDENTITY = "-"`)
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS`: „Automatically inject entitlements from the platform’s BaseEntitlements.plist into the code signatures of executables.“ [Beleg] ([Apple: Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)). Standardwert `YES` [Beleg] ([swift-build CoreBuildSystem.xcspec](https://raw.githubusercontent.com/swiftlang/swift-build/main/Sources/SWBCore/Specs/CoreBuildSystem.xcspec)).
- Apple schreibt dazu: „This setting tells Xcode to add the `com.apple.security.get-task-allow` entitlement to your app at build time.“ Beim Export über den Standard-Workflow entfernt Xcode das Entitlement. Abhilfe: „archive (as of Xcode 10.2) or export your app directly from Xcode, or set the `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` build setting to `NO` before building your app for distribution“ [Beleg] ([Apple: Resolving common notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)).
- DTS (Quinn) schrieb 2019 im Forum, nach seinem Verständnis bekämen nur Debug-Builds das Entitlement („my understanding“) ([Apple Forum 121268](https://developer.apple.com/forums/thread/121268)). Das ist informell und widerspricht der „at build time“-Formulierung oben. Darauf also nicht verlassen.

**Folge:** In der Release-Konfiguration `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` ausdrücklich setzen, in Debug `YES` lassen, damit das Debuggen funktioniert. Prüfen mit `codesign -d --entitlements :- TunnelTerminal.app` (Befehl aus der Notarisierungs-Doku).

### 3b) Keine absoluten Pfade im Binary

| Setting | Bedeutung (Quelle) | Standard |
|---|---|---|
| `DEPLOYMENT_POSTPROCESSING` | „If enabled, indicates that binaries should be stripped and file mode, owner, and group information should be set to standard values.“ ([Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)). Archivierte Referenz: Standard „`YES`: When `$ACTION = install`“, „Prerequisite for: STRIP_INSTALLED_PRODUCT“ ([Apple Archiv: Build Setting Reference](https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/1-Build_Setting_Reference/build_setting_ref.html)) | `NO` (xcspec) |
| `STRIP_INSTALLED_PRODUCT` | „If enabled, the linked product of the build will be stripped of symbols when performing deployment postprocessing.“ ([swift-build Strings](https://raw.githubusercontent.com/swiftlang/swift-build/main/Sources/SWBCore/Specs/en.lproj/CoreBuildSystem.strings)) | `YES` (xcspec) |
| `STRIP_STYLE` | `all`: „Completely strips the binary, removing the symbol table and relocation information“. `non-global`: „Strips non-global symbols, but saves external symbols“ (-x). `debugging`: „Strips debugging symbols, but saves local and global symbols“ (-S) (swift-build Strings). Archiv: `all` ist Standard für Apps und Kommandozeilenprodukte | `all` |
| `STRIP_SWIFT_SYMBOLS` | Passt `STRIP_STYLE` so an, dass beim Strippen „all Swift symbols will be removed“ (swift-build Strings) | `YES` |
| `COPY_PHASE_STRIP` | Strippt Binärdateien aus Copy-Phasen (z. B. **plink** in einer Copy-Files-Phase), „It does not cause the linked product of a target to be stripped“ ([Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)) | `YES` (xcspec). Was Projektvorlagen setzen, ist nicht belegt; im Projekt nachsehen |
| `DEBUG_INFORMATION_FORMAT` | `dwarf` oder `dwarf-with-dsym` (ebd.). Für die Weitergabe empfiehlt Apple „DWARF with dSYM File“ ([Apple: Building your app to include debugging information](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information)) | – |

**Woher die Pfade kommen**
- `dsymutil` holt die DWARF-Daten aus den Objektdateien „using debug symbol information contained in [the executable’s] symbol table“. Die Debug-Map ist „the list of the object files containing the debug information“ [Beleg] ([LLVM: dsymutil](https://llvm.org/docs/CommandGuide/dsymutil.html)). Diese Einträge sind Stabs, z. B. `N_OSO` („object file name“), `N_SO` („source file name“) und `N_AST` („AST file path“) [Beleg] ([cctools stab.h](https://raw.githubusercontent.com/apple-oss-distributions/cctools/main/include/mach-o/stab.h)). Darin stehen die absoluten DerivedData- und Quellpfade [Schluss].
- `strip -S` „Remove[s] the debugging symbol table entries“. `-x` „Remove[s] all local symbols (saving only global symbols)“. `-T` entfernt Swift-Symbole (`_$s…`) [Beleg] ([cctools strip.1](https://raw.githubusercontent.com/apple-oss-distributions/cctools/main/man/strip.1)). Dass `-S` die Debug-Map entfernt, folgt daraus [Schluss]. Ob `-x` allein auch die Stabs entfernt, steht in der Manpage nicht ausdrücklich [nicht belegt]. Gegenprüfen mit `dsymutil --dump-debug-map`.

**`xcodebuild build -configuration Release` und `xcodebuild archive` im Vergleich**
- `build`: `ACTION = build` → `DEPLOYMENT_POSTPROCESSING = NO` → das gelinkte Produkt wird **nicht** gestrippt, auch wenn `STRIP_INSTALLED_PRODUCT = YES` gesetzt ist. Die Debug-Map mit absoluten Pfaden bleibt im Binary. `get-task-allow` wird eingefügt, und es gibt keinen sicheren Zeitstempel [Schluss aus den Belegen oben; Zeitstempel: Notarisierungs-Doku].
- `archive`: Xcode legt die Produkte am Installationspfad im `.xcarchive` ab (siehe den Abschnitt „Skip Install“ in der [Notarisierungs-Doku](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)). Dabei wird nach `STRIP_STYLE` gestrippt, und `get-task-allow` fällt weg (Doku: „archive (as of Xcode 10.2)“). Dass Archive intern mit `ACTION = install` läuft, steht so nirgends wörtlich [nicht belegt].

**Swift und Clang**
- Swift: `-debug-prefix-map <prefix=replacement>` „Remap source paths in debug info“, `-file-prefix-map` „Remap source paths in debug, coverage, and index info“, `-file-compilation-dir <path>` [Beleg] ([Swift Options.td](https://raw.githubusercontent.com/swiftlang/swift/main/include/swift/Option/Options.td)). Dass `-file-prefix-map` auch `#filePath` umschreibt, steht dort nicht [nicht belegt]. Diese Flags betreffen DWARF (.o/dSYM). Die `N_OSO`-Objektpfade ändern sie vermutlich nicht [Schluss].
- Swift 6: `#file` hat das Format `<module-name>/<file-name>`, `#filePath` bleibt der volle Pfad. „The standard library's assertion and error functions will continue to use `#file`.“ [Beleg] ([SE-0274](https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0274-magic-file.md)). Folge: `fatalError` und `precondition` erzeugen im Swift-6-Modus keine absoluten Pfade. Eigener Code darf `#filePath` nicht verwenden [Schluss].
- Clang (für den plink-Bau): `-ffile-prefix-map=old=new` wird zu `-fdebug-prefix-map`, `-fmacro-prefix-map` und `-fcoverage-prefix-map` erweitert [Beleg] ([clang-Test debug-prefix-map.c](https://llvm.googlesource.com/llvm-project/clang/+/refs/heads/main/test/Driver/debug-prefix-map.c)). `-fdebug-compilation-dir` heißt „The compilation directory to embed in the debug info“ [Beleg] ([Clang Command Line Reference](https://clang.llvm.org/docs/ClangCommandLineReference.html)). `-fmacro-prefix-map` betrifft `__FILE__`, etwa in `assert()` [Schluss].

**Vorschlag für die Release-Konfiguration** (xcconfig-Auszug, [Schluss])
```
CODE_SIGN_IDENTITY                  = -
CODE_SIGN_INJECT_BASE_ENTITLEMENTS  = NO
ENABLE_HARDENED_RUNTIME             = YES
DEBUG_INFORMATION_FORMAT            = dwarf-with-dsym
DEPLOYMENT_POSTPROCESSING           = YES   // nötig, wenn per "xcodebuild build" statt "archive" gebaut wird
STRIP_INSTALLED_PRODUCT             = YES
STRIP_STYLE                         = all
OTHER_SWIFT_FLAGS                   = $(inherited) -file-prefix-map $(SRCROOT)=.
```
- plink: beim CMake-Bau `-ffile-prefix-map=<Quellverzeichnis>=.` setzen. plink selbst strippen (`strip -S`) oder `COPY_PHASE_STRIP = YES` mit „Code Sign On Copy“ nutzen. Danach die Signatur prüfen.
- Kontrolle: `strings -a <Binary> | grep -E '/Users/|DerivedData'` muss leer sein. `dsymutil --dump-debug-map <Binary>` darf keine Objektdateien mehr zeigen. Dazu `codesign -d --entitlements :-`.
- Bekanntes Risiko: Im Forum gibt es einen Bericht, dass `strip -S -T` (`STRIP_SWIFT_SYMBOLS = YES`) bei **eingebetteten Swift-Frameworks** die Chained Fixups beschädigt (Xcode 26.3 bis 27.0 b2, Swift 6.3, FB23528109). Der Workaround dort ist `STRIP_SWIFT_SYMBOLS = NO`. Apple-DTS hat den Bericht nur weitergeleitet, aber nicht bestätigt ([Apple Forum 836756](https://developer.apple.com/forums/thread/836756)). Für TunnelTerminal zählt das nur, wenn ein Swift-Framework eingebettet wird [Schluss].

---

## 4. PuTTY-Updates und Sicherheitsmeldungen

**Befunde**
- **putty-announce ist eingestellt.** Die Ankündigung von 0.85 trägt den Betreff „PuTTY 0.85 is released. Also MAILING LIST DISCONTINUED!“ (16.08.2026). Neue Releases werden künftig über einen RSS-Feed angekündigt [Beleg] ([lists.tartarus.org, putty-announce 2026/000043](https://lists.tartarus.org/pipermail/putty-announce/2026/000043.html)). Die Seite `maillist.html` erklärt: „We have a replacement announcement mechanism in the form of an RSS feed“ [Beleg] ([maillist.html, Spiegel](https://ftp.cvut.cz/putty/maillist.html)).
- **Feed-URL** (nur Release-Ankündigungen): **`https://www.chiark.greenend.org.uk/~sgtatham/putty/releases.rss`**. Weitere Kanäle: das Mastodon-Konto des PuTTY-Autors (auf `updates.html` verlinkt, enthält auch Fremdes), Usenet `comp.security.ssh` und die Windows-Store-Updatefunktion [Beleg] ([updates.html, Spiegel](https://ftp.cvut.cz/putty/updates.html); primär: `…/putty/updates.html`). Der Feed selbst war für das Abrufwerkzeug gesperrt und ist **nicht direkt geprüft**.
- **Aktuelle Version:** „Currently this is 0.85, released on 2026-08-16.“ [Beleg] ([latest.html, primär](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html), gleichlautend im [Spiegel](https://ftp.cvut.cz/putty/latest.html)).
- **Liste der Sicherheitslücken:** In der Wishlist hat jedes Release einen Abschnitt „Fixed in release …“ mit dem Unterpunkt „Security vulnerabilities“ ([wishlist, Spiegel](https://ftp.cvut.cz/putty/wishlist/); primär `…/putty/wishlist/`). Dazu kommen der CVE-Index `wishlist/cvelist.html` ([Spiegel](https://ftp.cvut.cz/putty/wishlist/cvelist.html)) und das Änderungsprotokoll `changes.html` ([Spiegel](https://ftp.cvut.cz/putty/changes.html)).
  - 0.85 (16.08.2026), fünf Lücken: `argon2-parameter-checks`, `etm-large-packet-overflow`, `maxpkt-0-tight-loop`, `pageant-deferred-decryption-uaf`, `ssh-greeting-unbounded`. Im CVE-Index ist dafür noch keine CVE eingetragen.
  - 0.84 (22.05.2026): `rsakex-double-free` (CVE-2026-48850), `telnet-trust-sigil` (CVE-2026-48851), `ecdsa-remotely-triggerable-assertion` (CVE-2026-48852) [Beleg] (Wishlist, cvelist und changes, alle Spiegel).
- **Ist 0.85 am 20.10.2026 noch die neueste Version?** Nach allem, was sich prüfen ließ: **ja**. `latest.html` nennt 0.85. Die Wishlist im Spiegel (zuletzt geändert am 11.10.2026) enthält keinen Abschnitt nach 0.85, das Änderungsprotokoll im Spiegel (25.08.2026) keinen neueren Eintrag. Eingeschränkt: Der RSS-Feed und der Stand vom 20.10. selbst sind nicht verifiziert.

**Folgen für die App**
- Mindestens plink 0.85 mitliefern. `maxpkt-0-tight-loop` und `ssh-greeting-unbounded` betreffen SSH-Verbindungen, `telnet-trust-sigil` (0.84) Telnet hinter Proxy [Schluss].
- Ein optionaler Update-Hinweis kann `releases.rss` per HTTPS lesen und mit der mitgelieferten Version vergleichen, aber ohne automatischen Download. In der Doku der App auf `latest.html` und die Wishlist verweisen.

---

## 5. About-Fenster und HTML-Import

**Befunde**
- `func orderFrontStandardAboutPanel(options optionsDictionary: [NSApplication.AboutPanelOptionKey : Any] = [:])`. Zusätzlich zu den Schlüsseln erlaubt: `"Copyright"`, sonst wird `NSHumanReadableCopyright` aus der lokalisierten Info.plist genommen [Beleg] ([Apple: orderFrontStandardAboutPanel(options:)](https://developer.apple.com/documentation/appkit/nsapplication/orderfrontstandardaboutpanel(options:))).
- Schlüssel: `.applicationIcon`, `.applicationName`, `.applicationVersion`, `.credits`, `.version` [Beleg] ([Apple: AboutPanelOptionKey](https://developer.apple.com/documentation/appkit/nsapplication/aboutpaneloptionkey)).
  - `.credits` (macOS 10.13+) erwartet einen `NSAttributedString`. Fehlt er, sucht AppKit in `Bundle.main` „“Credits.html”, “Credits.rtf”, and “Credits.rtfd”, in that order … The first file found is used“. Findet es nichts, bleibt der Bereich leer [Beleg] ([Apple: credits](https://developer.apple.com/documentation/appkit/nsapplication/aboutpaneloptionkey/credits)). **HTML hat also Vorrang vor RTF.**
  - `.applicationVersion` (10.13+) wird als „Version 1.0“ angezeigt. Ersatzweise nimmt AppKit `CFBundleShortVersionString`, sonst die Build-Version [Beleg] ([Apple: applicationVersion](https://developer.apple.com/documentation/appkit/nsapplication/aboutpaneloptionkey/applicationversion)).
  - `.version` (10.13+) ist die Build-Nummer und erscheint als `(v58.4)`. Ersatzweise nimmt AppKit `CFBundleVersion` [Beleg] ([Apple: version](https://developer.apple.com/documentation/appkit/nsapplication/aboutpaneloptionkey/version)).
- `init(data:options:documentAttributes:)` (macOS 10.0+): Mit `documentType = .html` „Don’t call this method from a background thread … it tries to synchronize with the main thread, fails, and times out. Calling it from the main thread works, but can still time out if the HTML contains references to external resources.“ Der HTML-Import ist für Markdown-artige Formatierung gedacht, „not for general HTML import“ [Beleg] ([Apple: init(data:options:documentAttributes:)](https://developer.apple.com/documentation/foundation/nsattributedstring/init(data:options:documentattributes:))).
- `init?(html:documentAttributes:)` (macOS 10.0+): „Apple discourages the use of this symbol. Use `loadFromHTML(data:options:completionHandler:)` instead.“ [Beleg] ([Apple: init(HTML:documentAttributes:)](https://developer.apple.com/documentation/foundation/nsattributedstring/init(html:documentattributes:))). Die Ersatzmethode gibt es ab macOS 10.15, asynchron mit `@Sendable`-Completion [Beleg] ([Apple: loadFromHTML](https://developer.apple.com/documentation/foundation/nsattributedstring/loadfromhtml(data:options:completionhandler:))).

**Folgen für die App**
- Für Credits und Lizenzen (PuTTY usw.) **`Credits.rtf`** verwenden, kein HTML. So läuft kein HTML-Import, es gibt keine Timeouts und keine externen Ressourcen [Schluss]. Nicht gleichzeitig `Credits.html` und `Credits.rtf` ins Bundle legen.
- Version und Build bei Bedarf ausdrücklich über `.applicationVersion` und `.version` übergeben, z. B. zusammen mit der plink-Version in den Credits.
- Falls doch HTML: nur auf dem MainActor und nur ohne externe Verweise wie `<img src="http…">` oder externes CSS.

---

## 6. Kontrast (WCAG 2.x) und App-Akzentfarbe

**WCAG-Formeln** [Beleg] ([W3C: Understanding 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html); Norm: [WCAG 2.2, W3C Recommendation vom 12.12.2024](https://www.w3.org/TR/WCAG22/))
- Relative Luminanz: `L = 0.2126 * R + 0.7152 * G + 0.0722 * B`, mit `C = CsRGB/12.92`, falls `CsRGB <= 0.04045`, sonst `C = ((CsRGB + 0.055)/1.055) ^ 2.4`, und `CsRGB = C8bit/255`. „Before May 2021 the value of 0.04045 … was different (0.03928)“, was „no practical effect“ hat.
- Kontrastverhältnis: `(L1 + 0.05) / (L2 + 0.05)`. L1 ist die hellere, L2 die dunklere Farbe.
- Grenzwerte: 1.4.3 verlangt für Text **4.5:1**. Für „large-scale text“ gilt **3:1**; groß heißt „at least 18 point or 14 point bold“. 1.4.11 Non-text Contrast verlangt **3:1** gegenüber angrenzenden Farben für UI-Komponenten und Zustände sowie für Grafikteile. Ausnahmen sind inaktive Komponenten und Darstellungen, die der User Agent bestimmt ([W3C: Understanding 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)).
- Wie WCAG-„point“ auf macOS-Punktgrößen umzurechnen ist, ist nicht belegt [nicht belegt].

**App-Akzentfarbe auf macOS**
- **Ja, nur bei „Mehrfarbig“.** Die HIG sagt: „Beginning in macOS 11, you can specify an accent color to customize the appearance of your app’s buttons, selection highlighting, and sidebar icons. The system applies your accent color when the current value in General > Accent color settings is multicolor.“ Wählt der Nutzer etwas anderes, ersetzt seine Farbe die der App. Ausnahme sind Seitenleisten-Symbole mit fester Farbe [Beleg] ([Apple HIG: Color → macOS → App accent colors](https://developer.apple.com/design/human-interface-guidelines/color)).
- `NSAccentColorName` (macOS 11+) steuert die „accent color (macOS) for the target“. Empfohlen ist, ihn über das Build-Setting „Global Accent Color Name“ setzen zu lassen [Beleg] ([Apple: NSAccentColorName](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaccentcolorname)). Der Setting-Name ist `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` [Beleg] ([Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)).
- `NSColor.controlAccentColor` (macOS 10.14+) ist „The user’s current accent color preference“, eingestellt „in the Appearance pane of System Settings“ [Beleg] ([Apple: controlAccentColor](https://developer.apple.com/documentation/appkit/nscolor/controlaccentcolor)). Die HIG nennt dagegen „General > Accent color“. Die Apple-Quellen widersprechen sich hier im Menüpfad.

**Folgen für die App**
- Kontraste nicht nur gegen die eigene Akzentfarbe prüfen, sondern gegen alle System-Akzentfarben, in Hell, Dunkel und mit „Kontrast erhöhen“. Selbst gezeichnete Elemente, etwa Status-Badges oder Terminal-Markierungen, sollen zur Laufzeit `controlAccentColor` verwenden und nicht die Asset-Farbe fest einbauen [Schluss].
- Für Terminal-Farbschemata 4.5:1 als Untergrenze für normalen Text ansetzen. Für Rahmen, Fokus und Statussymbole 3:1.
