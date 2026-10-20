import TunnelTerminalCore

/// Ziel einer Dateiübertragung aus dem Sheet (M6): Ordner bzw. Datei auf dem Server; der Benutzer nur, wenn die Sitzung
/// keinen nennt (geprüft wie im Sitzungs-Editor).
nonisolated struct TransferRequest: Sendable {
    let path: RemotePath
    let user: String?
}
