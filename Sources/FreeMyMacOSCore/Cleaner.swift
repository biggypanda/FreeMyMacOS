import Foundation

/// Something that could not be cleaned, and why.
public struct CleanFailure: Sendable, Equatable {
    public let path: String
    /// Short, human-readable English.
    public let reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public struct CleanReport: Sendable, Equatable {
    public let targetID: String
    /// Measured bytes of what was really deleted (or, in a dry run, what would be).
    public let freedBytes: Int64
    public let failures: [CleanFailure]

    public init(targetID: String, freedBytes: Int64, failures: [CleanFailure]) {
        self.targetID = targetID
        self.freedBytes = freedBytes
        self.failures = failures
    }
}

public protocol Cleaning: Sendable {
    func clean(_ target: CleanTarget) async -> CleanReport
}

/// Permanently deletes the children of a target's roots. Every item must pass
/// `SafetyGuard.validate` right before it is removed; an item that fails is left untouched.
///
/// Each item is removed in a single walk: entries are unlinked one by one (links are never
/// followed), folders are removed after their contents, and the allocated size of every entry
/// is added up as it goes. So `freedBytes` is exactly what left the disk, with no second pass.
public struct Cleaner: Cleaning {
    private let safetyGuard: SafetyGuard
    private let dryRun: Bool
    /// Bundle ids of the apps running right now, for `CleanTarget.appGuards`.
    private let runningBundleIDs: @Sendable () -> Set<String>
    /// Removes one entry (a file, a link, or a folder that is already empty).
    /// `unlink`/`rmdir` outside tests.
    private let removeEntry: @Sendable (URL) throws -> Void

    /// - Parameters:
    ///   - dryRun: when true nothing is deleted, and `freedBytes` reports what would be.
    ///   - runningBundleIDs: asked once per clean; a root guarded by a running app is skipped.
    public init(
        guard safetyGuard: SafetyGuard,
        dryRun: Bool = false,
        runningBundleIDs: @escaping @Sendable () -> Set<String> = { [] }
    ) {
        self.init(guard: safetyGuard, dryRun: dryRun, runningBundleIDs: runningBundleIDs,
                  remove: Self.removeEntry)
    }

    /// Test seam: lets a test stand in for the removal of each entry.
    init(
        guard safetyGuard: SafetyGuard,
        dryRun: Bool = false,
        runningBundleIDs: @escaping @Sendable () -> Set<String> = { [] },
        remove: @escaping @Sendable (URL) throws -> Void
    ) {
        self.safetyGuard = safetyGuard
        self.dryRun = dryRun
        self.runningBundleIDs = runningBundleIDs
        self.removeEntry = remove
    }

    /// Runs on the global concurrent executor, never on the caller's actor.
    /// Each root is handled on its own, so one unreadable root does not stop the others.
    @concurrent
    public func clean(_ target: CleanTarget) async -> CleanReport {
        let fileManager = FileManager()
        let running = target.appGuards.isEmpty ? [] : runningBundleIDs()
        var freed: Int64 = 0
        var failures: [CleanFailure] = []
        var reportedApps: Set<String> = []

        for root in target.roots {
            if let blocking = target.appGuard(for: root, running: running) {
                if reportedApps.insert(blocking.appName).inserted {
                    failures.append(CleanFailure(
                        path: blocking.folder.path,
                        reason: CoreText.quitFirst(blocking.appName)
                    ))
                }
                continue
            }

            let items: [URL]
            do {
                // A missing root yields [] and is not a failure.
                items = try target.deletableItems(in: root, fileManager: fileManager)
            } catch {
                // A root macOS will not let us read was never measured or offered
                // (the row asks for Full Disk Access instead), so skipping it is not a failure.
                if !Self.isPermission(error) {
                    failures.append(CleanFailure(path: root.path, reason: CoreText.couldNotRead))
                }
                continue
            }

            for item in items {
                do {
                    try safetyGuard.validate(item)
                } catch {
                    failures.append(CleanFailure(path: item.path, reason: Self.guardReason(error)))
                    continue
                }

                if dryRun {
                    freed += allocatedSize(of: item)
                    continue
                }
                let outcome = removeTree(item, fileManager: fileManager)
                freed += outcome.freed
                if let error = outcome.error {
                    failures.append(CleanFailure(path: item.path, reason: Self.removeReason(error)))
                }
            }
        }

        return CleanReport(targetID: target.id, freedBytes: freed, failures: failures)
    }

    /// Removes `url` and everything inside it, deepest first, without following links.
    /// Keeps going after an error so as much as possible is removed; returns the bytes of the
    /// entries really removed and the first error met.
    private func removeTree(_ url: URL, fileManager: FileManager) -> (freed: Int64, error: (any Error)?) {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            return (0, POSIXError(POSIXErrorCode(rawValue: errno) ?? .ENOENT))
        }
        var freed: Int64 = 0
        var firstError: (any Error)?

        if (info.st_mode & S_IFMT) == S_IFDIR {
            do {
                let children = try fileManager.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: []
                )
                for child in children {
                    let outcome = removeTree(child, fileManager: fileManager)
                    freed += outcome.freed
                    if firstError == nil { firstError = outcome.error }
                }
            } catch {
                firstError = firstError ?? error
            }
            // A folder that still has contents cannot go; its own error says less than the first one.
            if firstError != nil { return (freed, firstError) }
        }

        let size = Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?
            .totalFileAllocatedSize ?? 0)
        do {
            try removeEntry(url)
            freed += size
        } catch {
            // An entry that was already gone was not freed by this clean: credit nothing.
            firstError = firstError ?? error
        }
        return (freed, firstError)
    }

    /// The real removal: `rmdir` for a folder (already emptied), `unlink` for anything else,
    /// so a symbolic link is removed as the link itself.
    private static let removeEntry: @Sendable (URL) throws -> Void = { url in
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw POSIXError(Self.errnoCode) }
        let result = (info.st_mode & S_IFMT) == S_IFDIR ? rmdir(url.path) : unlink(url.path)
        if result != 0 { throw POSIXError(Self.errnoCode) }
    }

    private static var errnoCode: POSIXErrorCode {
        POSIXErrorCode(rawValue: errno) ?? .EIO
    }

    // MARK: - Helpers

    private static func guardReason(_ error: SafetyError) -> String {
        switch error {
        case .outsideAllowedRoots: CoreText.outsideAllowed
        case .isAllowedRootItself: CoreText.protectedFolder
        case .rootTooShallow: CoreText.unsafeLocation
        }
    }

    private static func removeReason(_ error: any Error) -> String {
        if isPermission(error) { return CoreText.permissionDenied }
        if isNoSuchFile(error) { return CoreText.noLongerExists }
        return CoreText.couldNotDelete
    }

    private static func posixCode(_ error: any Error) -> Int? {
        let ns = error as NSError
        if ns.domain == NSPOSIXErrorDomain { return ns.code }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain {
            return underlying.code
        }
        return nil
    }

    private static func isNoSuchFile(_ error: any Error) -> Bool {
        if let cocoa = error as? CocoaError,
           cocoa.code == .fileNoSuchFile || cocoa.code == .fileReadNoSuchFile {
            return true
        }
        return posixCode(error) == Int(ENOENT)
    }

    private static func isPermission(_ error: any Error) -> Bool {
        if let cocoa = error as? CocoaError,
           cocoa.code == .fileReadNoPermission || cocoa.code == .fileWriteNoPermission {
            return true
        }
        let code = posixCode(error)
        return code == Int(EACCES) || code == Int(EPERM)
    }
}
