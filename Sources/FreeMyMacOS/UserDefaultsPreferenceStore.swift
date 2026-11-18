import FreeMyMacOSCore
import Foundation

/// Keeps the selection choices and the clean history in the app's preferences
/// (~/Library/Preferences/com.pandacle.freemymacos.plist). Nothing leaves the Mac.
@MainActor
final class UserDefaultsPreferenceStore: PreferenceStore {
    private let defaults: UserDefaults
    private static let choicesKey = "selectionChoices"
    private static let historyKey = "cleanHistory"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectionChoices: [String: Bool] {
        get { defaults.dictionary(forKey: Self.choicesKey) as? [String: Bool] ?? [:] }
        set { defaults.set(newValue, forKey: Self.choicesKey) }
    }

    var history: [CleanRecord] {
        get {
            guard let data = defaults.data(forKey: Self.historyKey) else { return [] }
            return (try? JSONDecoder().decode([CleanRecord].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Self.historyKey)
        }
    }
}
