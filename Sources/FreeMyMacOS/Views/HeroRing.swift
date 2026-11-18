import FreeMyMacOSCore
import SwiftUI

/// Left side: the ring with the one big number, the Clean button and Rescan.
struct HeroPanel: View {
    let model: AppModel
    let diskTotal: Int64?
    let onClean: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 1 → 0 while a clean runs; drives the number flowing to zero and the ring emptying.
    @State private var cleanRemaining: Double = 1
    /// What the hero showed when the clean started.
    @State private var cleanStart = ByteParts(bytes: 0)
    @State private var cleanStartFraction: Double = 0
    @State private var isShowingFailures = false
    @State private var isShowingHistory = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HeroRing(fraction: ringFraction, isSpinning: model.phase == .scanning)
                center
            }
            .frame(width: Theme.ringDiameter, height: Theme.ringDiameter)

            Button(action: onClean) {
                Text(buttonTitle)
                    .contentTransition(.numericText())
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canClean)
            .padding(.top, Theme.heroButtonTopSpacing)

            Button("Rescan") { Task { await model.scan() } }
                .buttonStyle(GhostButtonStyle())
                .disabled(!canRescan)
                .padding(.top, Theme.heroSecondaryTopSpacing)
                // Hangs below Rescan without moving the ring and buttons.
                .overlay(alignment: .bottom) {
                    belowRescan
                        .fixedSize()
                        .alignmentGuide(.bottom) { $0[.top] - Theme.space4 }
                }
        }
        .padding(.horizontal, Theme.heroHorizontalPadding)
        .frame(maxHeight: .infinity)
        .animation(Theme.motion(reduced: reduceMotion), value: model.phase)
        .animation(reduceMotion ? nil : Theme.spring, value: liveBytes)
        .task(id: model.phase) { await flowToZeroIfCleaning() }
    }

    // MARK: - Below Rescan

    /// The failures of the last clean when there are any; otherwise when it last cleaned.
    @ViewBuilder
    private var belowRescan: some View {
        if !model.failures.isEmpty && model.phase != .cleaning {
            failuresLink
        } else if let last = model.lastClean, model.phase == .ready || model.phase == .idle {
            Button(lastCleanText(last)) { isShowingHistory = true }
                .buttonStyle(GhostButtonStyle(font: Theme.caption, idleColor: Theme.textTertiary))
                .popover(isPresented: $isShowingHistory, arrowEdge: .bottom) {
                    CleanHistoryPopover(history: model.history, targets: model.targets)
                }
                .transition(.opacity)
        }
    }

    private func lastCleanText(_ record: CleanRecord) -> String {
        let when = record.date.formatted(.relative(presentation: .named))
        return "Last cleaned \(when) · \(ByteFormat.string(record.freedBytes))"
    }

    // MARK: - Failures

    /// After a clean that left something behind: "N items couldn't be removed", which opens
    /// the list of paths. Shown from the done state until the next clean starts.
    @ViewBuilder
    private var failuresLink: some View {
        if !model.failures.isEmpty && model.phase != .cleaning {
            Button(failuresText) { isShowingFailures = true }
                .buttonStyle(GhostButtonStyle())
                .popover(isPresented: $isShowingFailures, arrowEdge: .bottom) {
                    CleanFailuresPopover(failures: model.failures)
                }
                .transition(.opacity)
        }
    }

    private var failuresText: String {
        let count = model.failures.count
        return count == 1 ? "1 item couldn't be removed" : "\(count) items couldn't be removed"
    }

    // MARK: - Center

    @ViewBuilder
    private var center: some View {
        if case .done(let freed) = model.phase {
            VStack(spacing: Theme.space10) {
                Image(systemName: "checkmark")
                    .font(Theme.heroCheck)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(model.isDryRun ? "Would free" : "Freed") \(ByteFormat.string(freed))")
                    .font(Theme.heroUnit)
                    .foregroundStyle(Theme.textSecondary)
            }
            .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : Theme.doneEntranceScale)))
        } else {
            VStack(spacing: Theme.space8) {
                Group {
                    // While numbers stream in or flow out, the text is redrawn every frame so the
                    // digits stay sharp; a per-digit transition would blur on every update.
                    if model.phase == .cleaning {
                        FlowingNumber(value: cleanStart.number * cleanRemaining, fixedFormat: cleanStart)
                    } else if model.phase == .scanning {
                        FlowingNumber(value: Double(liveBytes), fixedFormat: nil)
                    } else {
                        let parts = ByteParts(bytes: liveBytes)
                        Text(parts.text)
                            .contentTransition(.numericText(value: parts.number))
                    }
                }
                .font(Theme.heroNumber)
                .tracking(Theme.heroNumberTracking)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Theme.heroNumberMinimumScale)
                Text(unitText)
                    .font(Theme.heroUnit)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, Theme.ringLineWidth * 2)
            .transition(.opacity)
        }
    }

    /// Measured bytes the hero is about right now (before any clean flow).
    private var liveBytes: Int64 {
        switch model.phase {
        case .scanning: foundSoFar
        default: model.selectedBytes
        }
    }

    /// Safe-tier bytes found so far: what the scan will select when it ends.
    private var foundSoFar: Int64 {
        model.targets.reduce(Int64(0)) { sum, target in
            guard target.tier == .safe, let result = model.results[target.id], result.status == .ok
            else { return sum }
            return sum + result.bytes
        }
    }

    private var unitText: String {
        let unit = ByteParts(bytes: liveBytes).unit
        switch model.phase {
        case .idle, .scanning: return unit.map { "\($0) found so far" } ?? "Looking around"
        case .cleaning: return "Clearing"
        case .ready, .done: return unit.map { "\($0) can go" } ?? "Nothing selected"
        }
    }

    // MARK: - Ring

    private var ringFraction: Double {
        switch model.phase {
        case .idle: 0
        case .scanning: max(fraction(of: foundSoFar), Theme.ringScanningFraction)
        case .ready: fraction(of: model.selectedBytes)
        case .cleaning: cleanStartFraction * cleanRemaining
        case .done: 0
        }
    }

    /// Share of the disk, never smaller than the minimum visible arc when anything is selected.
    private func fraction(of bytes: Int64) -> Double {
        guard bytes > 0 else { return 0 }
        let minimum = Theme.ringMinimumDegrees / 360
        guard let diskTotal, diskTotal > 0 else { return minimum }
        return min(1, max(Double(bytes) / Double(diskTotal), minimum))
    }

    // MARK: - Buttons

    private var canClean: Bool { model.phase == .ready && model.selectedBytes > 0 }
    private var canRescan: Bool { model.phase == .ready || model.phase == .idle }

    private var buttonTitle: String {
        switch model.phase {
        case .idle, .scanning: "Scanning"
        case .cleaning: "Cleaning"
        case .done: "Done"
        case .ready: model.selectedBytes > 0 ? "Clean \(ByteFormat.string(model.selectedBytes))" : "Clean"
        }
    }

    // MARK: - Clean flow

    /// When a clean starts, the number flows to zero and the ring empties.
    /// With Reduce Motion it simply crossfades to zero.
    private func flowToZeroIfCleaning() async {
        guard model.phase == .cleaning else {
            cleanRemaining = 1
            return
        }
        cleanStart = ByteParts(bytes: model.selectedBytes)
        cleanStartFraction = fraction(of: model.selectedBytes)
        cleanRemaining = 1
        if reduceMotion {
            withAnimation(Theme.fade) { cleanRemaining = 0 }
            return
        }
        // A run of short spring steps: the springs blend into one steady count-down that
        // lasts about as long as a clean, instead of one 0.5 s drop.
        for step in 1...Theme.cleanFlowSteps {
            guard (try? await Task.sleep(for: Theme.cleanFlowStepInterval)) != nil else { return }
            let t = Double(step) / Double(Theme.cleanFlowSteps)
            withAnimation(Theme.spring) { cleanRemaining = pow(1 - t, 2) }
        }
    }
}

/// The paths the last clean could not remove, with the reason. A clean can leave thousands
/// behind, so the list is lazy and shows the first `shownLimit` only.
private struct CleanFailuresPopover: View {
    let failures: [CleanFailure]
    static let shownLimit = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Couldn't be removed")
                .font(Theme.groupHeader)
                .tracking(Theme.groupHeaderTracking)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, Theme.space8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.space8) {
                    ForEach(Array(failures.prefix(Self.shownLimit).enumerated()), id: \.offset) { _, failure in
                        VStack(alignment: .leading, spacing: Theme.space4 / 2) {
                            Text((failure.path as NSString).abbreviatingWithTildeInPath)
                                .font(Theme.detailItemName)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(failure.path)
                            Text(failure.reason)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if failures.count > Self.shownLimit {
                        Text("and \(failures.count - Self.shownLimit) more")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: min(Theme.failuresMaxHeight, CGFloat(min(failures.count, 8)) * Theme.failureRowEstimate))
        }
        .padding(Theme.popoverPadding)
        .frame(width: Theme.popoverWidth)
        .presentationCornerRadius(Theme.popoverCornerRadius)
    }
}

/// Past cleans, newest first.
private struct CleanHistoryPopover: View {
    let history: [CleanRecord]
    let targets: [CleanTarget]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent cleans")
                .font(Theme.groupHeader)
                .tracking(Theme.groupHeaderTracking)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, Theme.space8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.space8) {
                    ForEach(Array(history.reversed().enumerated()), id: \.offset) { _, record in
                        VStack(alignment: .leading, spacing: Theme.space4 / 2) {
                            HStack {
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(Theme.detailItemName)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer(minLength: Theme.space8)
                                Text(freedText(record))
                                    .font(Theme.detailItemSize)
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text(summary(record))
                                .font(Theme.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(2)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: min(Theme.failuresMaxHeight, CGFloat(min(history.count, 6)) * Theme.historyRowEstimate))
        }
        .padding(Theme.popoverPadding)
        .frame(width: Theme.popoverWidth)
        .presentationCornerRadius(Theme.popoverCornerRadius)
    }

    private func freedText(_ record: CleanRecord) -> String {
        record.isDryRun
            ? "Would free \(ByteFormat.string(record.freedBytes))"
            : ByteFormat.string(record.freedBytes)
    }

    private func summary(_ record: CleanRecord) -> String {
        let titles = record.targetIDs.compactMap { id in targets.first { $0.id == id }?.title }
        var text = titles.formatted(.list(type: .and))
        if record.failureCount > 0 {
            text += record.failureCount == 1
                ? " · 1 item couldn't be removed"
                : " · \(record.failureCount) items couldn't be removed"
        }
        return text
    }
}

/// The hero number while it moves: interpolated frame by frame.
/// With `fixedFormat` (cleaning) `value` is a number in that format's unit;
/// without it (scanning) `value` is a byte count, shown the way `ByteFormat` shows it.
private struct FlowingNumber: View, Animatable {
    nonisolated var value: Double
    let fixedFormat: ByteParts?

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        if let fixedFormat {
            Text(fixedFormat.formatted(max(value, 0)))
        } else {
            Text(ByteParts(bytes: Int64(max(value, 0).rounded())).text)
        }
    }
}

/// The 220 pt ring: a quiet track and the accent arc. Turns slowly while scanning.
struct HeroRing: View {
    let fraction: Double
    let isSpinning: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the current turn started; nil while the ring rests.
    @State private var spinStart: Date?
    /// Angle the ring rests at (always a whole number of turns once settled).
    @State private var restAngle: Double = 0

    var body: some View {
        TimelineView(.animation(paused: spinStart == nil)) { context in
            ZStack {
                Circle()
                    .stroke(Theme.stroke, lineWidth: Theme.ringLineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        Theme.accentArcGradient(degrees: fraction * 360, capDegrees: capDegrees),
                        style: StrokeStyle(lineWidth: Theme.ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90 + angle(at: context.date)))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .padding(Theme.ringLineWidth / 2)
        .onAppear { updateSpin() }
        .onChange(of: isSpinning) { updateSpin() }
        .onChange(of: reduceMotion) { updateSpin() }
        .accessibilityHidden(true)
    }

    /// Angle the round cap adds at each end of the arc.
    private var capDegrees: Double {
        let radius = (Theme.ringDiameter - Theme.ringLineWidth) / 2
        return Double(Theme.ringLineWidth / 2 / radius) * 180 / .pi
    }

    private func angle(at date: Date) -> Double {
        guard let spinStart else { return restAngle }
        return restAngle + date.timeIntervalSince(spinStart) / Theme.ringTurnDuration * 360
    }

    private func updateSpin() {
        let shouldSpin = isSpinning && !reduceMotion
        if shouldSpin, spinStart == nil {
            spinStart = .now
        } else if !shouldSpin, spinStart != nil {
            let current = angle(at: .now)
            spinStart = nil
            if reduceMotion {
                restAngle = 0
            } else {
                // Settle forward to the top instead of snapping back.
                restAngle = current
                withAnimation(Theme.spring) { restAngle = (current / 360).rounded(.up) * 360 }
            }
        }
    }
}

/// A byte count split for the hero: "23.94" over "GB can go".
struct ByteParts: Equatable {
    let number: Double
    let text: String
    /// nil for zero bytes.
    let unit: String?
    let decimals: Int

    init(bytes: Int64) {
        guard bytes > 0 else {
            self.init(number: 0, text: "0", unit: nil, decimals: 0)
            return
        }
        let parts = ByteFormat.string(bytes).split(separator: " ", maxSplits: 1).map(String.init)
        let text = parts.first ?? "0"
        let decimals = text.split(separator: ".").dropFirst().first?.count ?? 0
        self.init(
            number: Double(text.replacingOccurrences(of: ",", with: "")) ?? 0,
            text: text,
            unit: parts.count > 1 ? parts[1] : nil,
            decimals: decimals
        )
    }

    private init(number: Double, text: String, unit: String?, decimals: Int) {
        self.number = number
        self.text = text
        self.unit = unit
        self.decimals = decimals
    }

    /// `value` with the same number of decimals as this one.
    func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).locale(Locale(identifier: "en_US")))
    }
}

/// Full-width accent button, the only one on screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.primaryButtonFont)
            .monospacedDigit()
            .foregroundStyle(isEnabled ? Theme.onAccent : Theme.primaryIdleLabel)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.primaryButtonHeight)
            .background {
                // Accent only when it can be pressed; a quiet surface while it waits.
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                        .fill(Theme.surface)
                        .strokeBorder(Theme.stroke, lineWidth: Theme.hairline)
                    RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                        .fill(Theme.accentGradient)
                        .opacity(isEnabled ? 1 : 0)
                }
            }
            .scaleEffect(reduceMotion || !isEnabled ? 1 : (configuration.isPressed ? Theme.pressedScale : (isHovered ? Theme.hoverScale : 1)))
            .animation(Theme.motion(reduced: reduceMotion), value: configuration.isPressed)
            .animation(Theme.motion(reduced: reduceMotion), value: isHovered)
            .animation(Theme.motion(reduced: reduceMotion), value: isEnabled)
            .onHover { isHovered = $0 }
    }
}

/// Quiet text button: secondary text, a faint surface on hover.
struct GhostButtonStyle: ButtonStyle {
    var font: Font = Theme.body
    var idleColor: Color = Theme.textSecondary
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(isHovered && isEnabled ? Theme.textPrimary : idleColor)
            .padding(.horizontal, Theme.space12)
            .padding(.vertical, Theme.space6)
            .background(
                isHovered && isEnabled ? Theme.surfaceHover : .clear,
                in: .rect(cornerRadius: Theme.buttonCornerRadius)
            )
            .opacity(isEnabled ? (configuration.isPressed ? Theme.pressedOpacity : 1) : Theme.disabledOpacity)
            .contentShape(.rect)
            .animation(Theme.spring, value: isHovered)
            .onHover { isHovered = $0 }
    }
}
