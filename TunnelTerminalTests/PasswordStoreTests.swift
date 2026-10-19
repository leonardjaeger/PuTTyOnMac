import Security
import XCTest
@testable import TunnelTerminal

/// Passwörter im echten Schlüsselbund (S1), mit eigenem Dienstnamen je Test; nichts bleibt zurück (RL 3.9).
/// Nur Platzhalter-Ziele (S14).
@MainActor
final class PasswordStoreTests: XCTestCase {
    private var store: PasswordStore!

    override func setUp() async throws {
        store = PasswordStore(service: "\(AppIdentity.logSubsystem).tests.\(UUID().uuidString)")
        let service: String = store.service
        addTeardownBlock {
            SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
        }
    }

    func testSaveFindDelete() throws {
        XCTAssertFalse(store.contains(session: "Heim/Server"))
        try store.save("geh eim ä", session: "Heim/Server", target: "test@server.example:22")
        XCTAssertTrue(store.contains(session: "Heim/Server"))
        XCTAssertEqual(store.lookup(session: "Heim/Server", target: "test@server.example:22"), .found(Data("geh eim ä".utf8)))
        // Speichern ersetzt
        try store.save("neu", session: "Heim/Server", target: "test@server.example:22")
        XCTAssertEqual(store.lookup(session: "Heim/Server", target: "test@server.example:22"), .found(Data("neu".utf8)))
        store.delete(session: "Heim/Server")
        XCTAssertFalse(store.contains(session: "Heim/Server"))
        XCTAssertEqual(store.lookup(session: "Heim/Server", target: "test@server.example:22"), .none)
    }

    /// Die Sitzung zeigt inzwischen auf einen anderen Server/Benutzer/Port: das Passwort wird nicht herausgegeben.
    func testOtherTargetGetsNoPassword() throws {
        try store.save("geheim", session: "A", target: "test@server.example:22")
        XCTAssertEqual(store.lookup(session: "A", target: "test@server.example:2222"), .otherTarget)
        XCTAssertEqual(store.lookup(session: "A", target: "root@server.example:22"), .otherTarget)
        XCTAssertEqual(store.lookup(session: "B", target: "test@server.example:22"), .none)
    }

    func testRenameMovesEntry() throws {
        try store.save("geheim", session: "Alt", target: "test@server.example:22")
        store.rename(from: "Alt", to: "Gruppe/Neu")
        XCTAssertFalse(store.contains(session: "Alt"))
        XCTAssertEqual(store.lookup(session: "Gruppe/Neu", target: "test@server.example:22"), .found(Data("geheim".utf8)))
    }

    func testRejectsUnusablePasswords() {
        XCTAssertThrowsError(try store.save("", session: "A", target: "t"))
        XCTAssertThrowsError(try store.save("zeile\nzwei", session: "A", target: "t"))   // plink liest nur eine Zeile
        XCTAssertThrowsError(try store.save(String(repeating: "a", count: TerminalProcess.secretLimit + 1), session: "A", target: "t"))
        XCTAssertFalse(store.contains(session: "A"))
    }

    /// Nur dieses Gerät (keine iCloud-Synchronisation) und nicht in den Einstellungen der App (S1).
    func testEntryIsLocalAndNotInDefaults() throws {
        try store.save("nur-im-schluesselbund-1234", session: "A", target: "test@server.example:22")
        var result: CFTypeRef?
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: store.service,
                                      kSecAttrAccount: "A", kSecReturnAttributes: true, kSecMatchLimit: kSecMatchLimitOne]
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let attributes: [String: Any] = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotEqual(attributes[kSecAttrSynchronizable as String] as? Bool, true)
        XCTAssertEqual(attributes[kSecAttrLabel as String] as? String, "\(AppIdentity.name): A")
        let defaults: String = "\(UserDefaults.standard.dictionaryRepresentation())"
        XCTAssertFalse(defaults.contains("nur-im-schluesselbund-1234"))
    }

    /// Grund für den Anmelde-Schlüsselbund (docs/M3-Recherche.md 4): Ohne Entwickler-Team (Ad-hoc-Signatur) fehlt der
    /// Datenschutz-Schlüsselbund. Schlägt dieser Test fehl, ist er nutzbar geworden – dann dorthin wechseln.
    func testDataProtectionKeychainNeedsEntitlement() {
        let item: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: store.service,
                                     kSecAttrAccount: "Messung", kSecValueData: Data("x".utf8),
                                     kSecUseDataProtectionKeychain: true,
                                     kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status: OSStatus = SecItemAdd(item as CFDictionary, nil)
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: store.service,
                       kSecUseDataProtectionKeychain: true] as CFDictionary)
        XCTAssertEqual(status, errSecMissingEntitlement)
    }
}
