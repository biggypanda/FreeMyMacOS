import Foundation
import FreeMyMacOSCore

/// Fixed, plausible numbers for designing and screenshotting the interface.
/// Nothing here reads or deletes real files.
enum MockData {
    struct Entry {
        let bytes: Int64
        let itemCount: Int
        let status: ScanStatus
        let items: [(String, Int64)]
        /// When this target's result arrives during a scan.
        let delay: Double
        /// Roots (relative to home) shown as needing Full Disk Access.
        var deniedRoots: [String] = []
    }

    private static let gb: Int64 = 1_000_000_000
    private static let mb: Int64 = 1_000_000

    /// Targets not listed here come back `.missing` (hidden in the list).
    static let entries: [String: Entry] = [
        "xcode.derivedData": Entry(
            bytes: 8_134 * mb, itemCount: 9, status: .ok,
            items: [("SampleApp-abcdefghijklmnop", 3_412 * mb), ("DemoKit-qrstuvwxyzabcdef", 2_108 * mb),
                    ("ExampleWidget-ghijklmnopqrst", 1_496 * mb), ("ModuleCache.noindex", 812 * mb),
                    ("TestProject-uvwxyzabcdefgh", 214 * mb)],
            delay: 1.1),
        "xcode.simulatorCaches": Entry(
            bytes: 3_806 * mb, itemCount: 3, status: .ok,
            items: [("dyld", 3_104 * mb), ("IDS", 498 * mb), ("com.apple.CoreSimulator.SimRuntime", 204 * mb)],
            delay: 0.7),
        "xcode.deviceSupport": Entry(
            bytes: 12_214 * mb, itemCount: 3, status: .ok,
            items: [("iPhone17,1 27.1 (24B83)", 4_306 * mb), ("iPhone17,1 27.0 (24A335)", 4_102 * mb),
                    ("iPhone15,3 26.4 (23E246)", 3_806 * mb)],
            delay: 1.2),
        "swiftpm.cache": Entry(
            bytes: 642 * mb, itemCount: 3, status: .ok,
            items: [("repositories", 421 * mb), ("manifests", 151 * mb), ("artifacts", 70 * mb)],
            delay: 0.4),
        "node.cache": Entry(
            bytes: 2_318 * mb, itemCount: 3, status: .ok,
            items: [("~/.npm/_cacache", 1_604 * mb), ("~/Library/Caches/Yarn", 509 * mb),
                    ("~/Library/pnpm/store", 205 * mb)],
            delay: 0.9),
        "gradle.cache": Entry(
            bytes: 3_917 * mb, itemCount: 7, status: .ok,
            items: [("modules-2", 2_713 * mb), ("transforms-4", 806 * mb), ("jars-9", 297 * mb),
                    ("8.11", 88 * mb), ("journal-1", 9 * mb)],
            delay: 0.8),
        "homebrew.cache": Entry(
            bytes: 1_402 * mb, itemCount: 15, status: .ok,
            items: [("node--23.2.0.arm64_sequoia.bottle.tar.gz", 512 * mb),
                    ("python@3.13--3.13.0.arm64_sequoia.bottle.tar.gz", 401 * mb),
                    ("ffmpeg--7.1.arm64_sequoia.bottle.tar.gz", 298 * mb),
                    ("llvm--19.1.3.arm64_sequoia.bottle.tar.gz", 121 * mb),
                    ("git--2.47.0.arm64_sequoia.bottle.tar.gz", 31 * mb)],
            delay: 0.5),
        "browser.caches": Entry(
            bytes: 917 * mb, itemCount: 3, status: .ok,
            items: [("~/Library/Caches/Google/Chrome", 603 * mb), ("~/Library/Caches/Firefox", 198 * mb),
                    ("~/Library/Caches/company.thebrowser.Browser", 116 * mb)],
            delay: 0.6, deniedRoots: ["Library/Caches/com.apple.Safari"]),
        "cargo.registry": Entry(
            bytes: 1_204 * mb, itemCount: 2, status: .ok,
            items: [("~/.cargo/registry/src", 803 * mb), ("~/.cargo/registry/cache", 401 * mb)],
            delay: 0.55),
        "playwright.browsers": Entry(
            bytes: 1_890 * mb, itemCount: 4, status: .ok,
            items: [("chromium-1148", 612 * mb), ("firefox-1466", 498 * mb), ("webkit-2104", 471 * mb),
                    ("chromium_headless_shell-1148", 309 * mb)],
            delay: 0.65),
        "editor.caches": Entry(
            bytes: 1_116 * mb, itemCount: 6, status: .ok,
            items: [("~/Library/Application Support/Code/CachedExtensionVSIXs", 512 * mb),
                    ("~/Library/Application Support/Code/Cache", 288 * mb),
                    ("~/Library/Application Support/Cursor/CachedData", 201 * mb),
                    ("~/Library/Application Support/Code/GPUCache", 82 * mb),
                    ("~/Library/Application Support/Cursor/Code Cache", 33 * mb)],
            delay: 0.75),
        "chat.caches": Entry(
            bytes: 734 * mb, itemCount: 3, status: .ok,
            items: [("~/Library/Application Support/Slack/Cache", 402 * mb),
                    ("~/Library/Application Support/Slack/Service Worker/CacheStorage", 219 * mb),
                    ("~/Library/Application Support/discord/Cache", 113 * mb)],
            delay: 0.85),
        "user.caches": Entry(
            bytes: 2_611 * mb, itemCount: 36, status: .ok,
            items: [("com.example.MusicPlayer", 904 * mb), ("com.example.DesignTool", 611 * mb),
                    ("com.example.CodeEditor", 498 * mb), ("com.example.ChatApp", 302 * mb),
                    ("com.example.VideoCall", 187 * mb)],
            delay: 1.0),
        "user.logs": Entry(
            bytes: 318 * mb, itemCount: 11, status: .ok,
            items: [("DiagnosticReports", 211 * mb), ("CoreSimulator", 82 * mb), ("ExampleIDE", 14 * mb)],
            delay: 0.3),
        "trash": Entry(bytes: 0, itemCount: 0, status: .permissionDenied, items: [], delay: 0.35),
    ]

    /// Placeholder rows for the memory popover. Mock mode only: a real run shows real processes.
    private static let memoryApps: [(name: String, bytes: Int64)] = [
        ("Code Editor", 3_120 * mb), ("Web Browser", 1_840 * mb), ("Design Tool", 1_210 * mb),
        ("Chat", 742 * mb), ("Music", 488 * mb),
    ]

    /// Memory actions that touch no process: fixed rows, Quit and Free RAM do nothing.
    @MainActor
    static let memory = MemoryActions(
        topApps: {
            memoryApps.enumerated().map { index, app in
                // Negative ids so a mock row can never name a real process.
                AppMemory(id: pid_t(-(index + 1)), name: app.name, icon: nil, bytes: app.bytes)
            }
        },
        quit: { _ in },
        freeRAM: {
            try? await Task.sleep(for: .milliseconds(600))
            return .freed
        }
    )

    /// Two earlier cleans, so the "Last cleaned" line and its history show in mock mode.
    @MainActor
    static func preferences() -> InMemoryPreferenceStore {
        let day: TimeInterval = 86_400
        return InMemoryPreferenceStore(history: [
            CleanRecord(date: Date(timeIntervalSinceNow: -9 * day), freedBytes: 14_210 * mb,
                        targetIDs: ["xcode.derivedData", "node.cache", "user.caches"],
                        failureCount: 0, isDryRun: false),
            CleanRecord(date: Date(timeIntervalSinceNow: -2 * day), freedBytes: 6_402 * mb,
                        targetIDs: ["xcode.derivedData", "homebrew.cache", "browser.caches"],
                        failureCount: 3, isDryRun: false),
        ])
    }

    /// Opt-in debug hooks, honored only in mock mode.
    enum Hooks {
        /// `FMM_MOCK_EXPAND=<targetID>`: start with that row open.
        static var expandedID: String? {
            ProcessInfo.processInfo.environment["FMM_MOCK_EXPAND"]
        }
        /// `FMM_MOCK_AUTOCLEAN=<seconds>`: start a clean that many seconds after the scan finishes.
        static var autoCleanDelay: Double? {
            ProcessInfo.processInfo.environment["FMM_MOCK_AUTOCLEAN"].flatMap(Double.init)
        }
    }
}

/// Returns `MockData.entries` after a short staggered delay, so rows appear one by one.
struct MockScanner: Scanning {
    func scan(_ target: CleanTarget) async -> ScanResult {
        guard let entry = MockData.entries[target.id] else {
            // A folder that does not exist is known at once.
            try? await Task.sleep(for: .seconds(0.05))
            return ScanResult(targetID: target.id, bytes: 0, itemCount: 0, status: .missing, topItems: [])
        }
        try? await Task.sleep(for: .seconds(entry.delay))
        let root = target.roots.first ?? URL(fileURLWithPath: "/")
        let items = entry.items.map { name, bytes in
            ScanItem(url: root.appendingPathComponent(name), bytes: bytes, name: name)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ScanResult(
            targetID: target.id, bytes: entry.bytes, itemCount: entry.itemCount,
            status: entry.status, topItems: items,
            deniedRoots: entry.deniedRoots.map { home.appendingPathComponent($0, isDirectory: true) }
        )
    }
}

/// Pretends to clean: waits, reports the mock size as freed, deletes nothing.
struct MockCleaner: Cleaning {
    /// Whole clean takes about this long; split across the targets cleaned by default.
    private let totalDuration = 1.5

    func clean(_ target: CleanTarget) async -> CleanReport {
        let cleanedByDefault = MockData.entries.values.filter { $0.status == .ok }.count
        try? await Task.sleep(for: .seconds(totalDuration / Double(max(cleanedByDefault, 1))))
        return CleanReport(
            targetID: target.id, freedBytes: MockData.entries[target.id]?.bytes ?? 0, failures: []
        )
    }
}
