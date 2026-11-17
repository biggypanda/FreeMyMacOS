import AppKit
import FreeMyMacOSCore
import SwiftUI

@main
struct FreeMyMacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = Self.makeModel()
    /// The first scan runs once per launch, even if the window content appears again.
    @State private var didStart = false

    var body: some Scene {
        Window(Brand.name, id: "main") {
            RootView(
                model: model,
                memory: Self.memoryActions,
                initialExpandedID: Self.isMock ? MockData.Hooks.expandedID : nil
            )
                // The hidden title bar still counts toward the window height, so the content is
                // sized without it and then extends up into it: the whole window is 880 × 560.
                .frame(width: Theme.windowSize.width, height: Theme.windowSize.height - Self.titleBarHeight)
                .preferredColorScheme(.dark)
                .task { await start() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    // MARK: - Composition

    private static let titleBarHeight: CGFloat = {
        let content = NSRect(x: 0, y: 0, width: 100, height: 100)
        return NSWindow.frameRect(forContentRect: content, styleMask: [.titled]).height - content.height
    }()

    private static let home = FileManager.default.homeDirectoryForCurrentUser

    /// `FMM_MOCK=1` runs on fixed fake data and never touches the disk.
    private static var isMock: Bool {
        ProcessInfo.processInfo.environment["FMM_MOCK"] == "1"
    }

    /// `FMM_DRY_RUN=1` measures what a clean would free but deletes nothing.
    private static var isDryRun: Bool {
        ProcessInfo.processInfo.environment["FMM_DRY_RUN"] == "1"
    }

    @MainActor
    private static var memoryActions: MemoryActions { isMock ? MockData.memory : .live }

    /// The one place scanner and cleaner are chosen.
    @MainActor
    private static func makeModel() -> AppModel {
        let targets = TargetCatalog.all(home: home, ownBundleID: Brand.bundleID)
        if isMock {
            return AppModel(targets: targets, scanner: MockScanner(), cleaner: MockCleaner())
        }
        // Each root is checked on its own: one that resolves outside the home folder (say, a
        // symlinked cache folder) is left out of the guard, so its items fail closed in Cleaner
        // instead of stopping the whole app.
        let roots = targets.flatMap(\.roots).filter {
            (try? SafetyGuard(home: home, allowedRoots: [$0])) != nil
        }
        guard let safetyGuard = try? SafetyGuard(home: home, allowedRoots: roots) else {
            // Should not happen, but never fall back to anything unguarded: offer nothing.
            return AppModel(targets: [], scanner: DiskScanner(home: home), cleaner: NothingCleaner())
        }
        return AppModel(
            targets: targets,
            scanner: DiskScanner(home: home),
            cleaner: Cleaner(guard: safetyGuard, dryRun: isDryRun),
            isDryRun: isDryRun
        )
    }

    @MainActor
    private func start() async {
        guard !didStart else { return }
        didStart = true
        await model.scan()
        if Self.isMock, let delay = MockData.Hooks.autoCleanDelay {
            try? await Task.sleep(for: .seconds(delay))
            await model.clean()
        }
    }
}

/// Used only when no safety guard can be built: there are no targets, so it is never called,
/// and it deletes nothing if it is.
private struct NothingCleaner: Cleaning {
    func clean(_ target: CleanTarget) async -> CleanReport {
        CleanReport(targetID: target.id, freedBytes: 0, failures: [])
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
