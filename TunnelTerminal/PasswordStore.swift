import Foundation
import Security

/// Passwörter gespeicherter Sitzungen im Schlüsselbund (Plan M3, S1) – die einzige Stelle mit Schlüsselbund-Zugriff
/// (Grundsatz-Test). Freiwillig je Sitzung; ein Eintrag ist an `benutzer@server:port` der Sitzung gebunden
/// (`SessionFile.passwordTarget`) und wird für ein anderes Ziel nicht herausgegeben.
///
/// Anmelde-Schlüsselbund statt Datenschutz-Schlüsselbund: Ohne Entwickler-Team fehlt der App die Berechtigung dafür
/// (docs/M3-Recherche.md 4). Die Einträge sind lokal (nie synchronisiert); der Schlüsselbund erlaubt den Zugriff nur
/// der App, die sie angelegt hat – nach jedem neuen Bau (Ad-hoc-Signatur) fragt macOS deshalb einmal nach.
nonisolated struct PasswordStore: Sendable {
    nonisolated enum Lookup: Equatable, Sendable {
        case none
        /// Es gibt ein Passwort, aber für ein anderes Ziel (Sitzung geändert, importiert oder umbenannt).
        case otherTarget
        case found(Data)
    }

    nonisolated struct Failure: Error {
        let message: String
    }

    let service: String

    /// Speichert bzw. ersetzt das Passwort einer Sitzung.
    func save(_ password: String, session: String, target: String) throws(Failure) {
        let data: Data = Data(password.utf8)
        guard !data.isEmpty else { throw Failure(message: "Das Passwort ist leer.") }
        guard !password.contains(where: \.isNewline) else {
            throw Failure(message: "Das Passwort darf keinen Zeilenumbruch enthalten.")   // plink liest eine Zeile
        }
        guard data.count <= TerminalProcess.secretLimit else { throw Failure(message: "Das Passwort ist zu lang.") }
        delete(session: session)
        var item: [CFString: Any] = query(session)
        item[kSecValueData] = data
        item[kSecAttrGeneric] = Data(target.utf8)
        item[kSecAttrLabel] = "\(AppIdentity.name): \(session)"
        item[kSecAttrDescription] = "Passwort einer Sitzung"
        item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status: OSStatus = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure(message: Self.message(status)) }
    }

    /// Liest erst nur die Merkmale (ohne Rückfrage des Schlüsselbunds), das Passwort nur fürs richtige Ziel.
    func lookup(session: String, target: String) -> Lookup {
        guard let attributes = attributes(of: session) else { return .none }
        guard attributes[kSecAttrGeneric as String] as? Data == Data(target.utf8) else { return .otherTarget }
        var request: [CFString: Any] = query(session)
        request[kSecReturnData] = true
        request[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return .none
        }
        return .found(data)
    }

    func contains(session: String) -> Bool {
        attributes(of: session) != nil
    }

    func delete(session: String) {
        SecItemDelete(query(session) as CFDictionary)
    }

    /// Umbenennen der Sitzung nimmt das Passwort mit (Ziel und Inhalt bleiben).
    func rename(from oldName: String, to newName: String) {
        let changes: [CFString: Any] = [kSecAttrAccount: newName, kSecAttrLabel: "\(AppIdentity.name): \(newName)"]
        SecItemUpdate(query(oldName) as CFDictionary, changes as CFDictionary)
    }

    private func attributes(of session: String) -> [String: Any]? {
        var request: [CFString: Any] = query(session)
        request[kSecReturnAttributes] = true
        request[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? [String: Any]
    }

    private func query(_ session: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: session]
    }

    private static func message(_ status: OSStatus) -> String {
        let text: String = (SecCopyErrorMessageString(status, nil) as String?) ?? "Fehler \(status)"
        return "Schlüsselbund: \(text)"
    }
}
