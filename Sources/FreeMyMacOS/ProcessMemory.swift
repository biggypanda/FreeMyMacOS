import AppKit
import Darwin

/// One app in the memory popover.
struct AppMemory: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    /// Physical footprint (what Activity Monitor calls "Memory"), in bytes.
    let bytes: Int64
    /// The running app this row was measured from. Quit acts on this instance, never on a
    /// pid looked up again later (a pid can be reused by another app). nil in mock mode.
    var app: NSRunningApplication? = nil
}

/// The apps in the Dock (regular activation policy) and how much memory each uses.
@MainActor
enum ProcessMemory {
    /// The `limit` regular apps with the largest physical footprint, largest first.
    /// This app is left out; an app whose footprint cannot be read is skipped.
    static func topApps(limit: Int) -> [AppMemory] {
        let ownPID = getpid()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .compactMap { app -> AppMemory? in
                guard let bytes = footprint(of: app.processIdentifier) else { return nil }
                return AppMemory(
                    id: app.processIdentifier,
                    name: app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "App",
                    icon: app.icon,
                    bytes: bytes,
                    app: app
                )
            }
            .sorted { $0.bytes > $1.bytes }
            .prefix(limit)
            .map { $0 }
    }

    /// Asks the app to quit, the same as Quit in its menu. Never forces it.
    /// Acts only on the instance the row was built from: if that app has already quit,
    /// nothing happens, even if its pid now belongs to another app.
    static func quit(_ entry: AppMemory) {
        guard let app = entry.app, !app.isTerminated,
              app.processIdentifier != getpid() else { return }
        app.terminate()
    }

    /// `ri_phys_footprint` from `proc_pid_rusage`, or nil if the kernel refuses.
    private static func footprint(of pid: pid_t) -> Int64? {
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard status == 0 else { return nil }
        return Int64(clamping: info.ri_phys_footprint)
    }
}

/// What the memory strip can do. `.live` reads and acts on the real system;
/// mock mode uses `MockData.memory`, which never touches a process.
@MainActor
struct MemoryActions {
    let topApps: @MainActor () -> [AppMemory]
    let quit: @MainActor (AppMemory) -> Void
    /// Returns true only if memory was actually purged.
    let freeRAM: @MainActor () async -> PurgeResult

    static let popoverLimit = 5

    static let live = MemoryActions(
        topApps: { ProcessMemory.topApps(limit: popoverLimit) },
        quit: { ProcessMemory.quit($0) },
        freeRAM: { await Purge.run() }
    )
}
