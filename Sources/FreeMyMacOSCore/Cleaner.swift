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
public struct Cleaner: Cleaning {
    private let safetyGuard: SafetyGuard
    private let dryRun: Bool
    /// Removes one validated item. Always `FileManager.removeItem` outside tests.
    private let remove: @Sendable (URL) throws -> Void

    /// - Parameter dryRun: when true nothing is deleted, and `freedBytes` reports what would be.
    public init(guard safetyGuard: SafetyGuard, dryRun: Bool = false) {
        self.init(guard: safetyGuard, dryRun: dryRun) { try FileManager().removeItem(at: $0) }
    }

    /// Test seam: lets a test stand in for the removal step.
    init(guard safetyGuard: SafetyGuard, dryRun: Bool = false, remove: @escaping @Sendable (URL) throws -> Void) {
        self.safetyGuard = safetyGuard
        self.dryRun = dryRun
        self.remove = remove
    }

    /// Runs on the global concurrent executor, never on the caller's actor.
    /// Each root is handled on its own, so one unreadable root does not stop the others.
    @concurrent
    public func clean(_ target: CleanTarget) async -> CleanReport {
        let fileManager = FileManager()
        var freed: Int64 = 0
        var failures: [CleanFailure] = []

        for root in target.roots {
            let items: [URL]
            do {
                // A missing root yields [] and is not a failure.
                items = try target.deletableItems(in: root, fileManager: fileManager)
            } catch {
                failures.append(CleanFailure(path: root.path, reason: Self.listReason(error)))
                continue
            }

            for item in items {
                do {
                    try safetyGuard.validate(item)
                } catch {
                    failures.append(CleanFailure(path: item.path, reason: Self.guardReason(error)))
                    continue
                }

                let before = allocatedSize(of: item)
                if dryRun {
                    freed += before
                    continue
                }
                do {
                    try remove(item)
                    freed += before
                } catch {
                    // An item that was already gone was not freed by this clean: credit nothing.
                    // Otherwise a folder may be partly gone before removal failed: count only what left.
                    if !Self.isNoSuchFile(error) {
                        let after = Self.exists(item) ? allocatedSize(of: item) : 0
                        freed += max(0, before - after)
                    }
                    failures.append(CleanFailure(path: item.path, reason: Self.removeReason(error)))
                }
            }
        }

        return CleanReport(targetID: target.id, freedBytes: freed, failures: failures)
    }

    // MARK: - Helpers

    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    private static func guardReason(_ error: SafetyError) -> String {
        switch error {
        case .outsideAllowedRoots: "Outside the allowed folders"
        case .isAllowedRootItself: "Is a protected folder"
        case .rootTooShallow: "Unsafe location"
        }
    }

    private static func listReason(_ error: any Error) -> String {
        isPermission(error) ? "Permission denied" : "Could not read folder"
    }

    private static func removeReason(_ error: any Error) -> String {
        if isPermission(error) { return "Permission denied" }
        if isNoSuchFile(error) { return "No longer exists" }
        return "Could not delete"
    }

    private static func isNoSuchFile(_ error: any Error) -> Bool {
        if let cocoa = error as? CocoaError,
           cocoa.code == .fileNoSuchFile || cocoa.code == .fileReadNoSuchFile {
            return true
        }
        let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
        return underlying?.domain == NSPOSIXErrorDomain && underlying?.code == Int(ENOENT)
    }

    private static func isPermission(_ error: any Error) -> Bool {
        if let cocoa = error as? CocoaError,
           cocoa.code == .fileReadNoPermission || cocoa.code == .fileWriteNoPermission {
            return true
        }
        let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
        return underlying?.domain == NSPOSIXErrorDomain
            && (underlying?.code == Int(EACCES) || underlying?.code == Int(EPERM))
    }
}
