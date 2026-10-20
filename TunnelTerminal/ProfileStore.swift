import Foundation
import Observation
import TunnelTerminalCore

/// Die Profile der App (Plan M4), eine Liste für alle Fenster, als JSON in den Einstellungen (keine Geheimnisse, S1).
/// Nach jeder Änderung meldet `didChange`; offene Terminals übernehmen das neue Aussehen.
@Observable
final class ProfileStore {
    static let didChange: Notification.Name = Notification.Name("TunnelTerminalProfileDidChange")
    private static let key: String = "Profile"

    private(set) var profiles: [TerminalProfile]
    @ObservationIgnored private let defaults: UserDefaults

    /// `defaults` nur für Tests ändern (eigene Suite statt der Einstellungen der App).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        profiles = TerminalProfile.list(from: defaults.data(forKey: Self.key))
    }

    /// Unbekannte oder gelöschte Profile: das Standardprofil.
    func profile(id: UUID?) -> TerminalProfile {
        profiles.first { $0.id == id } ?? profiles[0]
    }

    func update(_ profile: TerminalProfile) throws(InputError) {
        try TerminalProfile.checkName(profile.name)
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        guard !profiles.contains(where: { $0.id != profile.id && $0.name == profile.name }) else {
            throw .profileNameTaken
        }
        profiles[index] = profile.clamped
        save()
    }

    /// Neues Profil als Kopie mit freiem Namen („Dunkel Kopie“, „Dunkel Kopie 2“ …).
    @discardableResult
    func add(copying source: TerminalProfile) -> TerminalProfile {
        var copy: TerminalProfile = source
        copy.id = UUID()
        let base: String = String("\(source.name) Kopie".prefix(TerminalProfile.nameLimit - 3))
        copy.name = base
        var number: Int = 2
        while profiles.contains(where: { $0.name == copy.name }) {
            copy.name = "\(base) \(number)"
            number += 1
        }
        profiles.append(copy)
        save()
        return copy
    }

    /// Das Standardprofil bleibt. Sitzungen mit dem gelöschten Profil zeigen danach das Standardprofil.
    func remove(id: UUID) {
        guard id != TerminalProfile.standardID else { return }
        profiles.removeAll { $0.id == id }
        save()
    }

    private func save() {
        // Kodieren scheitert bei diesen Werten nicht; falls doch, bleibt der alte Stand stehen statt gelöscht zu werden
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Self.key)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
