// Erzeugt von build/m2/putty-zahlen-schluessel.py aus dem Quellcode von PuTTY 0.85 (conf.h, settings.c).
// Nicht von Hand ändern, sondern neu erzeugen.

/// Einstellungen, die Windows-PuTTY als Zahl (`REG_DWORD`) in der Registrierung ablegt.
/// Alle übrigen Schlüssel sind Zeichenketten (`REG_SZ`).
enum PuTTYSettingKeys {
    static let integerKeys: Set<String> = [
        "ANSIColour", "AddressFamily", "AgentFwd", "AltF4", "AltOnly", "AltSpace", "AlwaysOnTop", "ApplicationCursorKeys",
        "ApplicationKeypad", "AuthGSSAPI", "AuthGSSAPIKEX", "AuthKI", "AuthTIS", "AutoWrapMode", "BCE", "BackspaceIsDelete",
        "Beep", "BeepInd", "BellOverload", "BellOverloadN", "BellOverloadS", "BellOverloadT", "BlinkCur", "BlinkText",
        "BoldAsColour", "BoldFontCharSet", "BoldFontHeight", "BoldFontIsBold", "BugChanReq", "BugDHGEx2", "BugDeriveKey2",
        "BugDropStart", "BugFilterKexinit", "BugHMAC2", "BugIgnore1", "BugIgnore2", "BugMaxPkt2", "BugOldGex2",
        "BugPKSessID2", "BugPlainPW1", "BugRSA1", "BugRSAPad2", "BugRSASHA2CertUserauth", "BugRekey2", "BugWinadj",
        "BuggyMAC", "CJKAmbigWide", "CRImpliesLF", "CapsLockCyr", "ChangeUsername", "CloseOnExit", "ComposeKey",
        "Compression", "ConnectionSharing", "ConnectionSharingDownstream", "ConnectionSharingUpstream", "CtrlAltKeys",
        "CurType", "DECOriginMode", "DisableArabicShaping", "DisableBidi", "DisableBracketedPaste", "EraseToScrollback",
        "FontCharSet", "FontHeight", "FontIsBold", "FontQuality", "FontVTMode", "FullScreenOnAltEnter", "GssapiFwd",
        "GssapiRekey", "HideMousePtr", "LFImpliesCR", "LinuxFunctionKeys", "LocalEcho", "LocalEdit", "LocalPortAcceptAll",
        "LockSize", "LogFileClash", "LogFlush", "LogHeader", "LogType", "LoginShell", "MouseAutocopy", "MouseIsXterm",
        "MouseOverride", "NetHackKeypad", "NoAltScreen", "NoApplicationCursors", "NoApplicationKeys", "NoDBackspace",
        "NoMouseReporting", "NoPTY", "NoRemoteCharset", "NoRemoteClearScroll", "NoRemoteQTitle", "NoRemoteResize",
        "NoRemoteWinTitle", "OSXCommandMeta", "OSXOptionMeta", "PassiveTelnet", "PasteControls", "PasteRTF", "PingInterval",
        "PingIntervalSecs", "PortNumber", "PreferKnownHostKeys", "Present", "ProxyDNS", "ProxyLocalhost", "ProxyLogToTerm",
        "ProxyMethod", "ProxyPort", "ProxySOCKSVersion", "ProxyType", "RFCEnviron", "RXVTHomeEnd", "RawCNP", "RectSelect",
        "RekeyTime", "RemotePortAcceptAll", "RemoteQTitleAction", "SSH2DES", "SSHLogOmitData", "SSHLogOmitPasswords",
        "SUPDUPCharset", "SUPDUPMoreProcessing", "SUPDUPScrolling", "ScrollBar", "ScrollBarFullScreen", "ScrollOnDisp",
        "ScrollOnKey", "ScrollbackLines", "ScrollbarOnLeft", "SerialDataBits", "SerialFlowControl", "SerialParity",
        "SerialSpeed", "SerialStopHalfbits", "ShadowBold", "ShadowBoldOffset", "ShiftedArrowKeys", "SshBanner",
        "SshNoAuth", "SshNoShell", "SshNoTrivialAuth", "SshProt", "StampUtmp", "SunkenEdge", "TCPKeepalives", "TCPNoDelay",
        "TelnetKey", "TelnetRet", "TermHeight", "TermWidth", "TrueColour", "TryAgent", "TryPalette", "UTF8Override",
        "UTF8linedraw", "UseSystemColours", "UserNameFromEnvironment", "WarnOnClose", "WideBoldFontCharSet", "WideBoldFontHeight",
        "WideBoldFontIsBold", "WideFontCharSet", "WideFontHeight", "WideFontIsBold", "WinNameAlways", "WindowBorder",
        "X11AuthType", "X11Forward", "Xterm256Colour"
    ]
}
