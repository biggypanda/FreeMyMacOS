import AppKit
import FreeMyMacOSCore
import SwiftUI

/// One target. Clicking the row opens its detail; only the round mark changes the selection.
/// With the keyboard: Tab focuses a row, Space selects it, → opens and ← closes its detail.
struct TargetRow: View {
    let target: CleanTarget
    let result: ScanResult?
    let isSelected: Bool
    let canToggle: Bool
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onToggleSelected: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let privacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )!

    private var isDenied: Bool { result?.status == .permissionDenied }
    /// Readable, but some of its folders need Full Disk Access.
    private var isPartlyDenied: Bool { result?.status == .ok && result?.deniedRoots.isEmpty == false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                TargetDetail(target: target, result: result)
                    .transition(.opacity)
            }
        }
        .background(background, in: .rect(cornerRadius: Theme.rowCornerRadius))
        .clipShape(.rect(cornerRadius: Theme.rowCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .strokeBorder(Theme.focusRing, lineWidth: Theme.focusRingWidth)
                .opacity(isFocused ? 1 : 0)
        }
        .animation(Theme.spring, value: isHovered)
    }

    private var background: Color {
        if isExpanded { return Theme.surface }
        return isHovered ? Theme.surfaceHover : .clear
    }

    private var header: some View {
        HStack(spacing: Theme.rowSpacing) {
            Image(systemName: target.symbol)
                .font(Theme.rowIcon)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: Theme.rowIconWidth)

            HStack(spacing: Theme.space6) {
                Text(target.title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(Theme.chevron)
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .transaction { if reduceMotion { $0.animation = nil } }
            }

            Spacer(minLength: Theme.space8)

            if isPartlyDenied {
                Image(systemName: "exclamationmark.triangle")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.warning)
                    .help("Some of these folders need Full Disk Access")
                    .accessibilityLabel("Some folders need Full Disk Access")
            }

            if target.tier == .careful && !isDenied {
                Text("Review first")
                    .font(Theme.marker)
                    .foregroundStyle(Theme.warning)
            }

            trailingValue

            Button { if canToggle { onToggleSelected() } } label: {
                SelectionMark(isSelected: isSelected && !isDenied, isEnabled: canToggle, isLocked: isDenied)
            }
            .buttonStyle(.plain)
            // The row itself takes keyboard focus (Space selects), so the mark is not a second stop.
            .focusable(false)
            .disabled(!canToggle)
            .accessibilityLabel("Select \(target.title)")
            .accessibilityAddTraits(isSelected && !isDenied ? .isSelected : [])
        }
        .padding(.horizontal, Theme.rowHorizontalPadding)
        .frame(height: Theme.rowHeight)
        .contentShape(.rect)
        .onTapGesture(perform: onToggleExpanded)
        .onHover { isHovered = $0 }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.space) {
            if canToggle { onToggleSelected() }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if !isExpanded { onToggleExpanded() }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if isExpanded { onToggleExpanded() }
            return .handled
        }
        .accessibilityAction(named: isExpanded ? "Hide details" : "Show details", onToggleExpanded)
    }

    @ViewBuilder
    private var trailingValue: some View {
        if isDenied {
            TextLink(title: "Grant access", color: Theme.warning) {
                NSWorkspace.shared.open(Self.privacySettingsURL)
            }
        } else if let result {
            Text(ByteFormat.string(result.bytes))
                .font(Theme.size)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .transition(.opacity)
        }
    }
}

/// The opened part of a row: what it is, the largest items, and where it lives.
private struct TargetDetail: View {
    let target: CleanTarget
    let result: ScanResult?

    /// Size column lines up with the row's size (mark width + spacing + padding).
    private let trailingInset = Theme.selectionDotSize + Theme.rowSpacing + Theme.rowHorizontalPadding

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(target.detail)
                .font(Theme.detail)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(Theme.detailLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, trailingInset)
                .padding(.bottom, Theme.space8)

            if result?.status == .permissionDenied {
                Text("Reading this folder needs Full Disk Access. Turn it on for \(Brand.name) in Privacy settings, then rescan.")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(Theme.detailLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, trailingInset)
                HStack {
                    Spacer()
                    TextLink(title: "Open Privacy settings", color: Theme.textSecondary) {
                        NSWorkspace.shared.open(TargetRow.privacySettingsURL)
                    }
                }
                .padding(.top, Theme.space6)
                .padding(.trailing, trailingInset)
            } else {
                if let denied = result?.deniedRoots, !denied.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.space6) {
                        Text(partialAccessText(denied))
                            .font(Theme.detail)
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(Theme.detailLineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Theme.space8)
                        TextLink(title: "Open Privacy settings", color: Theme.warning) {
                            NSWorkspace.shared.open(TargetRow.privacySettingsURL)
                        }
                    }
                    .padding(.trailing, trailingInset)
                    .padding(.bottom, Theme.space8)
                }
                if let result {
                    ForEach(result.topItems) { item in
                        HStack(spacing: Theme.space12) {
                            Text(item.name)
                                .font(Theme.detailItemName)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: Theme.space8)
                            Text(ByteFormat.string(item.bytes))
                                .font(Theme.detailItemSize)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(height: Theme.detailItemHeight)
                        .padding(.trailing, trailingInset)
                    }
                }
                HStack {
                    if let more = remainingCount, more > 0 {
                        Text("and \(more) more")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    TextLink(title: "Show in Finder", color: Theme.textSecondary) {
                        NSWorkspace.shared.activateFileViewerSelecting(target.roots)
                    }
                }
                .padding(.top, Theme.space4)
                .padding(.trailing, trailingInset)
            }
        }
        .padding(.leading, Theme.detailIndent)
        .padding(.bottom, Theme.space12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func partialAccessText(_ denied: [URL]) -> String {
        let names = denied
            .map { ($0.path as NSString).abbreviatingWithTildeInPath }
            .formatted(.list(type: .and))
        return denied.count == 1
            ? "\(names) needs Full Disk Access, so it is not counted."
            : "\(names) need Full Disk Access, so they are not counted."
    }

    private var remainingCount: Int? {
        guard let result, result.status == .ok else { return nil }
        return result.itemCount - result.topItems.count
    }
}

/// The round selection mark. Monochrome: the accent belongs to the ring and the button.
private struct SelectionMark: View {
    let isSelected: Bool
    let isEnabled: Bool
    let isLocked: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.textTertiary, lineWidth: Theme.selectionDotLineWidth)
                .opacity(isSelected ? 0 : 1)
            Circle()
                .fill(Theme.textPrimary)
                .opacity(isSelected ? 1 : 0)
                .scaleEffect(isSelected || reduceMotion ? 1 : Theme.markEntranceScale)
            Image(systemName: "checkmark")
                .font(Theme.checkGlyph)
                .foregroundStyle(Theme.background)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: Theme.selectionDotSize, height: Theme.selectionDotSize)
        .opacity(isLocked ? Theme.lockedOpacity : 1)
        .padding(Theme.selectionMarkHitSlop)
        .contentShape(.circle)
        .padding(-Theme.selectionMarkHitSlop)
    }
}

/// Small text button that brightens on hover.
struct TextLink: View {
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.caption)
                .foregroundStyle(isHovered ? Theme.textPrimary : color)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Theme.spring, value: isHovered)
    }
}
