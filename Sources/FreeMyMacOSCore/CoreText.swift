import Foundation

/// User-visible text produced by the core (failure reasons, catalog titles and details).
/// Translations live in the app bundle (Contents/Resources/<lang>.lproj/Localizable.strings),
/// so lookups go to the main bundle; without one (tests, `swift run`) the English key is used.
enum CoreText {
    static var outsideAllowed: String { String(localized: "Outside the allowed folders") }
    static var protectedFolder: String { String(localized: "Is a protected folder") }
    static var unsafeLocation: String { String(localized: "Unsafe location") }
    static var permissionDenied: String { String(localized: "Permission denied") }
    static var couldNotRead: String { String(localized: "Could not read folder") }
    static var noLongerExists: String { String(localized: "No longer exists") }
    static var couldNotDelete: String { String(localized: "Could not delete") }
    static func quitFirst(_ appName: String) -> String { String(localized: "Quit \(appName) first") }

    /// A catalog string (title or detail) whose English text is its key.
    static func catalog(_ english: String) -> String {
        Bundle.main.localizedString(forKey: english, value: english, table: nil)
    }
}
