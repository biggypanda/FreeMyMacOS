import AppKit
import FreeMyMacOSCore
import SwiftUI

/// Bottom strip: memory in use, the apps using the most (popover), and Free RAM.
struct MemoryStrip: View {
    let actions: MemoryActions

    @State private var stats = MemoryStats.current()
    @State private var apps: [AppMemory] = []
    @State private var isShowingApps = false
    @State private var isPurging = false
    /// Short note next to Free RAM after it ran, cleared after a few seconds.
    @State private var purgeNote: PurgeResult?
    /// The numbers refresh only while the window can be seen.
    @State private var isWindowVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.memoryStripSpacing) {
            Button {
                if !isShowingApps { apps = actions.topApps() }
                isShowingApps.toggle()
            } label: {
                HStack(spacing: Theme.memoryStripSpacing) {
                    Text("Memory")
                    bar
                    Text(usageText)
                        .monospacedDigit()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Memory, \(usageText)")
            .accessibilityHint("Shows the apps using the most memory")
            .popover(isPresented: $isShowingApps, arrowEdge: .top) {
                MemoryAppsPopover(apps: apps, onQuit: quit)
            }

            // Runs `purge` behind the system's administrator prompt. For a few seconds after,
            // the button says how it went.
            Button(purgeButtonTitle) { freeRAM() }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isPurging)
                .help("Asks for your administrator password, then runs purge")
                .accessibilityHint("Asks for your administrator password")
        }
        .animation(Theme.motion(reduced: reduceMotion), value: purgeNote)
        .task(id: purgeNote) {
            guard purgeNote != nil else { return }
            guard (try? await Task.sleep(for: Theme.purgeNoteDuration)) != nil else { return }
            purgeNote = nil
        }
        .font(Theme.caption)
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, Theme.memoryStripPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.stroke).frame(height: Theme.hairline)
        }
        .background(WindowVisibilityReader(isVisible: $isWindowVisible))
        .task(id: isWindowVisible) {
            // Light refresh while the window is visible: one kernel call every few seconds.
            // Hidden, minimized or covered: the task ends and nothing runs.
            guard isWindowVisible else { return }
            refresh()
            while !Task.isCancelled {
                guard (try? await Task.sleep(for: Theme.memoryRefreshInterval)) != nil else { return }
                refresh()
            }
        }
    }

    private func refresh() {
        withAnimation(Theme.motion(reduced: reduceMotion)) {
            stats = MemoryStats.current()
            if isShowingApps { apps = actions.topApps() }
        }
    }

    private func quit(_ app: AppMemory) {
        actions.quit(app)
        // An app may take a moment to quit (or ask to save first): look again shortly.
        Task {
            guard (try? await Task.sleep(for: Theme.quitRefreshDelay)) != nil else { return }
            refresh()
        }
    }

    private func freeRAM() {
        guard !isPurging else { return }
        isPurging = true
        purgeNote = nil
        Task {
            let result = await actions.freeRAM()
            if result == .freed { refresh() }
            purgeNote = result
            isPurging = false
        }
    }

    private var purgeButtonTitle: String {
        if isPurging { return String(localized: "Freeing…") }
        return purgeNote.map(noteText) ?? String(localized: "Free RAM")
    }

    private func noteText(_ result: PurgeResult) -> String {
        switch result {
        case .freed: String(localized: "Memory freed")
        case .cancelled: String(localized: "Cancelled")
        case .failed: String(localized: "Couldn't free memory")
        }
    }

    private var usedFraction: Double {
        guard let stats, stats.total > 0 else { return 0 }
        return Double(stats.used) / Double(stats.total)
    }

    private var bar: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Theme.stroke)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.memoryFill)
                        .frame(width: proxy.size.width * usedFraction)
                }
        }
        .frame(height: Theme.memoryBarHeight)
    }

    /// "11.2 of 16 GB": memory is counted in binary units, like Activity Monitor and About This Mac.
    private var usageText: String {
        guard let stats else { return String(localized: "Unavailable") }
        return MemoryText.usage(used: stats.used, total: stats.total)
    }
}

enum MemoryText {
    /// "11.2 of 16 GB" ("11,2 / 16 GB" in Turkish): binary units, like Activity Monitor.
    static func usage(used: Int64, total: Int64, locale: Locale = .current) -> String {
        let gib = Double(1 << 30)
        let style = FloatingPointFormatStyle<Double>.number.locale(locale)
        let usedText = (Double(used) / gib).formatted(style.precision(.fractionLength(1)))
        let totalText = (Double(total) / gib).formatted(style.precision(.fractionLength(0)))
        return String(localized: "\(usedText) of \(totalText) GB", locale: locale)
    }
}

/// The apps using the most memory, each with Quit.
private struct MemoryAppsPopover: View {
    let apps: [AppMemory]
    let onQuit: (AppMemory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Using the most memory")
                .font(Theme.groupHeader)
                .tracking(Theme.groupHeaderTracking)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, Theme.space8)
            if apps.isEmpty {
                Text("No apps to show")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(height: Theme.popoverRowHeight)
            }
            ForEach(apps) { app in
                HStack(spacing: Theme.rowSpacing) {
                    Text(app.name)
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: Theme.space8)
                    Text(ByteFormat.string(app.bytes))
                        .font(Theme.size)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    TextLink(title: "Quit", color: Theme.textTertiary) { onQuit(app) }
                        .accessibilityLabel("Quit \(app.name)")
                }
                .frame(height: Theme.popoverRowHeight)
            }
        }
        .padding(Theme.popoverPadding)
        .frame(width: Theme.popoverWidth)
        .presentationCornerRadius(Theme.popoverCornerRadius)
    }
}

/// Reports whether the hosting window is visible on screen (not minimized, hidden or
/// fully covered), using the window's occlusion state.
private struct WindowVisibilityReader: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = { isVisible = $0 }
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {
        nsView.onChange = { isVisible = $0 }
    }

    final class ReaderView: NSView {
        var onChange: ((Bool) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.didChangeOcclusionStateNotification, object: nil
            )
            if let window {
                NotificationCenter.default.addObserver(
                    self, selector: #selector(occlusionChanged),
                    name: NSWindow.didChangeOcclusionStateNotification, object: window
                )
            }
            report()
        }

        @objc private func occlusionChanged(_ notification: Notification) {
            report()
        }

        private func report() {
            let visible = window?.occlusionState.contains(.visible) ?? false
            // Not during SwiftUI's own view update.
            Task { @MainActor in self.onChange?(visible) }
        }
    }
}

/// Small bordered button for the strip.
struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.caption)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, Theme.smallButtonPadding)
            .frame(height: Theme.smallButtonHeight)
            .background(
                isHovered ? Theme.surfaceHover : Theme.surface,
                in: .rect(cornerRadius: Theme.buttonCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                    .strokeBorder(Theme.stroke, lineWidth: Theme.hairline)
            )
            .opacity(configuration.isPressed ? Theme.pressedOpacity : 1)
            .animation(Theme.spring, value: isHovered)
            .onHover { isHovered = $0 }
    }
}
