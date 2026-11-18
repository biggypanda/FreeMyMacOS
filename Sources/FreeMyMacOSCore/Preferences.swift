import Foundation

/// One finished clean, kept so the app can show when it last cleaned and what it freed.
public struct CleanRecord: Codable, Equatable, Sendable {
    public let date: Date
    public let freedBytes: Int64
    /// Ids of the targets that were cleaned.
    public let targetIDs: [String]
    public let failureCount: Int
    /// True when nothing was really deleted (a measuring-only run).
    public let isDryRun: Bool

    public init(date: Date, freedBytes: Int64, targetIDs: [String], failureCount: Int, isDryRun: Bool) {
        self.date = date
        self.freedBytes = freedBytes
        self.targetIDs = targetIDs
        self.failureCount = failureCount
        self.isDryRun = isDryRun
    }
}

/// Where `AppModel` keeps what should outlive a launch: the user's own selection choices and
/// the clean history. The app stores them in its preferences; tests keep them in memory.
@MainActor
public protocol PreferenceStore: AnyObject {
    /// Target id → the user's last explicit choice (selected or not).
    var selectionChoices: [String: Bool] { get set }
    /// Oldest first.
    var history: [CleanRecord] { get set }
}

@MainActor
public final class InMemoryPreferenceStore: PreferenceStore {
    public var selectionChoices: [String: Bool]
    public var history: [CleanRecord]

    public init(selectionChoices: [String: Bool] = [:], history: [CleanRecord] = []) {
        self.selectionChoices = selectionChoices
        self.history = history
    }
}
