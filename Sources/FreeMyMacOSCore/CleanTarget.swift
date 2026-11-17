import Foundation

public enum CleanGroup: String, Sendable, CaseIterable {
    case developer, browsers, system
}

public enum CleanTier: Sendable {
    case safe, careful
}

/// A fixed location whose contents can be removed. The roots themselves are kept.
public struct CleanTarget: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    /// One sentence: what it is and why it is safe to delete.
    public let detail: String
    /// SF Symbol name.
    public let symbol: String
    public let group: CleanGroup
    public let tier: CleanTier
    /// Absolute, standardized folders whose children are removed.
    public let roots: [URL]
    /// Direct children of a root that are never touched.
    public let excludedNames: Set<String>
    /// Direct children of a root whose name starts with one of these are never touched.
    public let excludedPrefixes: [String]

    public init(
        id: String,
        title: String,
        detail: String,
        symbol: String,
        group: CleanGroup,
        tier: CleanTier,
        roots: [URL],
        excludedNames: Set<String> = [],
        excludedPrefixes: [String] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.group = group
        self.tier = tier
        self.roots = roots
        self.excludedNames = excludedNames
        self.excludedPrefixes = excludedPrefixes
    }
}
