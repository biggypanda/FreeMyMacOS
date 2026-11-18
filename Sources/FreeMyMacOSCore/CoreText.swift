import Foundation

/// User-visible text produced by the core (failure reasons).
enum CoreText {
    static var outsideAllowed: String { "Outside the allowed folders" }
    static var protectedFolder: String { "Is a protected folder" }
    static var unsafeLocation: String { "Unsafe location" }
    static var permissionDenied: String { "Permission denied" }
    static var couldNotRead: String { "Could not read folder" }
    static var noLongerExists: String { "No longer exists" }
    static var couldNotDelete: String { "Could not delete" }
    static func quitFirst(_ appName: String) -> String { "Quit \(appName) first" }
}
