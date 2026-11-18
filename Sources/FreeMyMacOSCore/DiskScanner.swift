import Foundation

public enum ScanStatus: Sendable, Equatable {
    case ok, missing, permissionDenied
}

public struct ScanResult: Sendable, Equatable {
    public let targetID: String
    public let bytes: Int64
    /// Direct children of the roots, excluded children not counted.
    public let itemCount: Int
    public let status: ScanStatus
    /// Direct children, largest first, at most 5.
    public let topItems: [ScanItem]
    /// Roots that exist but could not be listed (usually missing Full Disk Access).
    /// Non-empty with status `.ok` means the row is only partly readable.
    public let deniedRoots: [URL]

    public init(
        targetID: String, bytes: Int64, itemCount: Int, status: ScanStatus,
        topItems: [ScanItem], deniedRoots: [URL] = []
    ) {
        self.targetID = targetID
        self.bytes = bytes
        self.itemCount = itemCount
        self.status = status
        self.topItems = topItems
        self.deniedRoots = deniedRoots
    }
}

public struct ScanItem: Sendable, Equatable, Identifiable {
    public let url: URL
    public let bytes: Int64
    /// Display name, fixed when the item is measured: the last path component for a
    /// single-root target, or a "~/..." path relative to the home folder for a multi-root one.
    public let name: String
    public var id: URL { url }

    public init(url: URL, bytes: Int64, name: String) {
        self.url = url
        self.bytes = bytes
        self.name = name
    }
}

public protocol Scanning: Sendable {
    func scan(_ target: CleanTarget) async -> ScanResult
}

/// Measures what each target would free. Read-only: it never deletes anything.
public struct DiskScanner: Scanning {
    private let home: URL

    /// - Parameter home: used only to build "~/..." display names for multi-root targets.
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL
    }

    /// Runs on the global concurrent executor, never on the caller's actor.
    /// When the task is cancelled it stops early and returns what it measured so far.
    @concurrent
    public func scan(_ target: CleanTarget) async -> ScanResult {
        let fileManager = FileManager()
        let multiRoot = target.roots.count > 1
        var items: [ScanItem] = []
        var existingRoots = 0
        var deniedRoots: [URL] = []

        for root in target.roots {
            if Task.isCancelled { break }
            let children: [URL]
            switch target.listing(of: root, fileManager: fileManager) {
            case .missing:
                continue
            case .denied:
                existingRoots += 1
                deniedRoots.append(root)
                continue
            case .items(let urls):
                existingRoots += 1
                children = urls
            }
            for child in children {
                if Task.isCancelled { break }
                items.append(ScanItem(
                    url: child,
                    bytes: allocatedSize(of: child),
                    name: multiRoot ? displayPath(of: child) : child.lastPathComponent
                ))
            }
        }

        let bytes = items.reduce(Int64(0)) { $0 + $1.bytes }
        let status: ScanStatus
        if existingRoots == 0 {
            status = .missing
        } else if !deniedRoots.isEmpty && bytes == 0 {
            status = .permissionDenied
        } else {
            status = .ok
        }
        let top = items
            .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.url.path < $1.url.path }
            .prefix(5)
        return ScanResult(
            targetID: target.id, bytes: bytes, itemCount: items.count,
            status: status, topItems: Array(top), deniedRoots: deniedRoots
        )
    }

    /// "~/" + the path relative to home, or the full path when the item is not under home.
    private func displayPath(of url: URL) -> String {
        let base = home.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.count > base.count,
              Array(components.prefix(base.count)) == base
        else { return url.standardizedFileURL.path }
        return "~/" + components.dropFirst(base.count).joined(separator: "/")
    }
}

/// Allocated bytes of `url` on disk: a file's own size, or the sum over everything inside
/// a directory. A symbolic link counts as the link itself; links are never followed and
/// enumeration never descends into a symlinked directory. Unreadable entries count as 0.
/// Stops early (returning the partial sum) when the current task is cancelled.
func allocatedSize(of url: URL) -> Int64 {
    let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isSymbolicLinkKey, .isDirectoryKey]
    guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }
    var total = Int64(values.totalFileAllocatedSize ?? 0)
    // `isDirectory` describes the item itself, so a link to a folder is not a directory here.
    guard values.isDirectory == true, values.isSymbolicLink != true else { return total }

    guard let enumerator = FileManager().enumerator(
        at: url,
        includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isSymbolicLinkKey],
        options: [],
        errorHandler: { _, _ in true }
    ) else { return total }

    for case let child as URL in enumerator {
        if Task.isCancelled { break }
        let size = (try? child.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?
            .totalFileAllocatedSize ?? 0
        total += Int64(size)
    }
    return total
}

enum RootListing {
    case missing
    case denied
    case items([URL])
}

extension CleanTarget {
    /// The direct children of the roots that a clean would remove, exclusions applied.
    /// A root that does not exist, or that is itself a symbolic link, contributes nothing.
    /// A root that exists but cannot be listed throws. Cleaner uses this too.
    public func deletableItems(fileManager: FileManager = .default) throws -> [URL] {
        var result: [URL] = []
        for root in roots {
            result += try deletableItems(in: root, fileManager: fileManager)
        }
        return result
    }

    /// Per-root variant: `[]` for a missing or symlinked root, throws when the root cannot
    /// be listed. A root that is a link is never followed, so it counts as missing.
    func deletableItems(in root: URL, fileManager: FileManager = .default) throws -> [URL] {
        guard !Self.isSymbolicLink(root) else { return [] }
        do {
            return try fileManager
                .contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [])
                .filter { !isExcluded($0.lastPathComponent) }
        } catch let error as CocoaError where Self.isMissing(error) {
            return []
        }
    }

    func listing(of root: URL, fileManager: FileManager) -> RootListing {
        guard Self.exists(root), !Self.isSymbolicLink(root) else { return .missing }
        do {
            return .items(try deletableItems(in: root, fileManager: fileManager))
        } catch let error as CocoaError where Self.isMissing(error) {
            return .missing
        } catch {
            return .denied
        }
    }

    func isExcluded(_ name: String) -> Bool {
        excludedNames.contains(name) || excludedPrefixes.contains { name.hasPrefix($0) }
    }

    /// True if something (even a dangling link) is at `url`.
    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    /// True if `url` itself is a symbolic link (checked with lstat, so the link is not followed).
    private static func isSymbolicLink(_ url: URL) -> Bool {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return false }
        return (info.st_mode & S_IFMT) == S_IFLNK
    }

    /// Missing root, or a root that is not a folder (nothing to clean inside it).
    private static func isMissing(_ error: CocoaError) -> Bool {
        if error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return true }
        if let posix = error.userInfo[NSUnderlyingErrorKey] as? POSIXError {
            return posix.code == .ENOENT || posix.code == .ENOTDIR
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain {
            return underlying.code == Int(ENOENT) || underlying.code == Int(ENOTDIR)
        }
        return false
    }
}
