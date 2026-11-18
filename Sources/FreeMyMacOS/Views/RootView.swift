import AppKit
import FreeMyMacOSCore
import SwiftUI

/// The one window: hero on the left, target list on the right, memory strip at the bottom.
struct RootView: View {
    @Bindable var model: AppModel
    let memory: MemoryActions
    let commands: CommandActions
    /// Which row is open. Lives here, not in `AppModel`: it is pure presentation.
    @State var expandedID: String?
    @State private var isConfirmingClean = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let diskTotal = DiskSpace.current(for: FileManager.default.homeDirectoryForCurrentUser)?.total

    init(model: AppModel, memory: MemoryActions, commands: CommandActions = CommandActions(),
         initialExpandedID: String? = nil) {
        self.model = model
        self.memory = memory
        self.commands = commands
        _expandedID = State(initialValue: initialExpandedID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HeroPanel(model: model, diskTotal: diskTotal, onClean: requestClean)
                    .frame(width: Theme.heroWidth)
                TargetList(model: model, expandedID: $expandedID)
            }
            MemoryStrip(actions: memory)
                .frame(height: Theme.memoryStripHeight)
        }
        .foregroundStyle(Theme.textPrimary)
        .background(Backdrop())
        .background(WindowConfigurator())
        .ignoresSafeArea()
        .confirmationDialog(
            "Clean items marked Review first?",
            isPresented: $isConfirmingClean,
            titleVisibility: .visible
        ) {
            Button("Clean", role: .destructive) { startClean() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .onChange(of: commands.cleanRequests) {
            guard model.phase == .ready, model.selectedBytes > 0 else { return }
            requestClean()
        }
        .task(id: model.phase) {
            // Hold "Freed …" for a moment, then go back to the list.
            guard case .done = model.phase else { return }
            guard (try? await Task.sleep(for: Theme.doneHoldDuration)) != nil else { return }
            withAnimation(Theme.motion(reduced: reduceMotion)) {
                model.acknowledgeDone()
            }
        }
    }

    private var confirmationMessage: String {
        let names = model.targets
            .filter { $0.tier == .careful && model.selection.contains($0.id) && model.results[$0.id]?.status == .ok }
            .map(\.title)
            .formatted(.list(type: .and))
        return "\(names) will be removed for good. This can't be undone."
    }

    private func requestClean() {
        if model.needsConfirmation {
            isConfirmingClean = true
        } else {
            startClean()
        }
    }

    private func startClean() {
        Task { await model.clean() }
    }
}

/// Near-black background with a faint accent glow behind the hero.
private struct Backdrop: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.accentStart.opacity(Theme.glowOpacity), .clear],
                center: Theme.glowCenter,
                startRadius: 0,
                endRadius: Theme.glowRadius
            )
        }
        .ignoresSafeArea()
    }
}

/// Lets the window be dragged by its background (macOS 14 has no SwiftUI modifier for it).
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ConfiguringView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ConfiguringView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isMovableByWindowBackground = true
        }
    }
}
