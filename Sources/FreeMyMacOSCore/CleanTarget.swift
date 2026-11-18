import Foundation

public enum CleanGroup: String, Sendable, CaseIterable {
    case developer, browsers, apps, system
}

/// An app whose data folder must not be cleaned while it runs: it holds its caches open
/// and may write them back or break. Roots inside `folder` are skipped while any of
/// `bundleIDs` is running.
public struct AppGuard: Sendable, Hashable {
    public let appName: String
    public let bundleIDs: [String]
    public let folder: URL

    public init(appName: String, bundleIDs: [String], folder: URL) {
        self.appName = appName
        self.bundleIDs = bundleIDs
        self.folder = folder.standardizedFileURL
    }

    /// True when `url` is `folder` or inside it, compared by whole path components.
    func covers(_ url: URL) -> Bool {
        let base = folder.pathComponents
        let components = url.standardizedFileURL.pathComponents
        return components.count >= base.count && Array(components.prefix(base.count)) == base
    }
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
    /// Apps that must be quit before roots inside their folder are cleaned.
    public let appGuards: [AppGuard]

    public init(
        id: String,
        title: String,
        detail: String,
        symbol: String,
        group: CleanGroup,
        tier: CleanTier,
        roots: [URL],
        excludedNames: Set<String> = [],
        excludedPrefixes: [String] = [],
        appGuards: [AppGuard] = []
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
        self.appGuards = appGuards
    }

    /// The guard that blocks `root` right now, if any: one covering it whose app is running.
    func appGuard(for root: URL, running: Set<String>) -> AppGuard? {
        appGuards.first { guardItem in
            guardItem.covers(root) && guardItem.bundleIDs.contains(where: running.contains)
        }
    }
}
