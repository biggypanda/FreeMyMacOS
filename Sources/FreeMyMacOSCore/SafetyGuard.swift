import Foundation

public enum SafetyError: Error, Equatable {
    /// The item is not strictly inside any allowed root, or that cannot be proven.
    case outsideAllowedRoots
    /// The item is an allowed root itself. Roots are kept; only their contents go.
    case isAllowedRootItself
    /// An allowed root is too close to (or not inside) the home folder.
    case rootTooShallow
}

/// The gate every deletion must pass.
///
/// Rules:
/// - Every allowed root must be at least two path components below `home`, or be exactly
///   `home/.Trash`. A root that is not inside `home` at all also throws `.rootTooShallow`.
/// - `home` and the roots are canonicalized with `realpath(3)` (the longest existing prefix
///   is resolved, any missing tail is kept as written), so `/var` vs `/private/var` and
///   symlinked folders compare correctly.
/// - For an item, only its **parent** is resolved; the last component is appended as is,
///   so a symlink item is judged (and later deleted) as the link, never its destination.
///   The resolved path must be strictly inside an allowed root.
/// - Fail-closed: an item path containing `..`, or whose parent folder does not exist and so
///   cannot be resolved, throws `.outsideAllowedRoots`. Rejecting `..` (rather than folding it
///   away lexically) avoids disagreeing with the kernel when `..` follows a symlink.
/// - Comparison is by whole path components, never by string prefix.
public struct SafetyGuard: Sendable {
    private let roots: [[String]]

    public init(home: URL, allowedRoots: [URL]) throws(SafetyError) {
        let homeComponents = Self.canonicalComponents(home)
        var roots: [[String]] = []
        for root in allowedRoots {
            let components = Self.canonicalComponents(root)
            guard components.count > homeComponents.count,
                  Array(components.prefix(homeComponents.count)) == homeComponents
            else { throw .rootTooShallow }
            let depth = components.count - homeComponents.count
            let isTrash = depth == 1 && components.last == ".Trash"
            guard depth >= 2 || isTrash else { throw .rootTooShallow }
            roots.append(components)
        }
        self.roots = roots
    }

    public func validate(_ item: URL) throws(SafetyError) {
        guard item.isFileURL,
              let components = Self.lexicalComponents(item.path),
              components.count >= 2,
              let name = components.last
        else { throw .outsideAllowedRoots }

        let parentPath = NSString.path(withComponents: Array(components.dropLast()))
        guard let realParent = Self.realpath(parentPath) else { throw .outsideAllowedRoots }
        let candidate = (realParent as NSString).pathComponents + [name]

        if roots.contains(candidate) { throw .isAllowedRootItself }
        let inside = roots.contains { root in
            candidate.count > root.count && Array(candidate.prefix(root.count)) == root
        }
        guard inside else { throw .outsideAllowedRoots }
    }

    // MARK: - Paths

    /// Absolute path components with `.` and empty components dropped.
    /// Returns nil when the path is relative or contains `..`.
    private static func lexicalComponents(_ path: String) -> [String]? {
        guard path.hasPrefix("/") else { return nil }
        var result = ["/"]
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".": continue
            case "..": return nil
            default: result.append(String(component))
            }
        }
        return result
    }

    /// Components of `url` with its longest existing prefix resolved by `realpath(3)`.
    /// `..` is folded lexically here; this is only used for trusted inputs (home and roots).
    private static func canonicalComponents(_ url: URL) -> [String] {
        var components = (url.standardizedFileURL.path as NSString).pathComponents
        var tail: [String] = []
        while components.count > 1 {
            if let resolved = realpath(NSString.path(withComponents: components)) {
                return (resolved as NSString).pathComponents + tail
            }
            tail.insert(components.removeLast(), at: 0)
        }
        return ["/"] + tail
    }

    private static func realpath(_ path: String) -> String? {
        guard let resolved = Darwin.realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
