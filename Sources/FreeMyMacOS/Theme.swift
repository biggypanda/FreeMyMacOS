import SwiftUI

enum Brand {
    static let name = "FreeMyMacOS"
    static let bundleID = "com.pandacle.freemymacos"
}

/// Every color, size and motion value the views use. Views never hard-code these.
enum Theme {
    // MARK: Color

    static let background = Color(hex: 0x0B0D12)
    static let surface = Color.white.opacity(0.04)
    static let surfaceHover = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.08)

    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
    /// About 4.6:1 on the background, enough for small text.
    static let textTertiary = Color.white.opacity(0.48)

    /// The only accent. Used as a gradient on the ring and the primary button, nowhere else
    /// (plus the faint background glow).
    static let accentStart = Color(hex: 0x5EF2C4)
    static let accentEnd = Color(hex: 0x3AA8FF)
    static let accentGradient = LinearGradient(
        colors: [accentStart, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// The accent running start → end along an arc that begins at 0° and sweeps `degrees`.
    /// `capDegrees` widens it by the round caps so they keep their end's color.
    static func accentArcGradient(degrees: Double, capDegrees: Double) -> AngularGradient {
        AngularGradient(
            colors: [accentStart, accentEnd],
            center: .center,
            startAngle: .degrees(-capDegrees),
            endAngle: .degrees(max(degrees, 0) + capDegrees)
        )
    }
    /// Label color on top of the accent gradient.
    static let onAccent = Color(hex: 0x06231C)

    /// Fill of the memory bar.
    static let memoryFill = Color.white.opacity(0.45)

    /// Careful-tier marker and permission state only.
    static let warning = Color(hex: 0xFFB454)
    /// Keyboard focus around a row.
    static let focusRing = Color.white.opacity(0.55)
    static let focusRingWidth: CGFloat = 1.5
    /// How long the note after Free RAM stays.
    static let purgeNoteDuration: Duration = .seconds(3)
    /// Height estimates that size the failures and history popovers to their content.
    static let failureRowEstimate: CGFloat = 40
    static let historyRowEstimate: CGFloat = 44

    /// Glow behind the hero: starts top-left of the window center, opacity ≤ 0.10.
    static let glowOpacity = 0.10
    static let glowCenter = UnitPoint(x: 0.19, y: 0.36)
    static let glowRadius: CGFloat = 420

    // MARK: Layout

    static let windowSize = CGSize(width: 880, height: 560)
    static let heroWidth: CGFloat = 340
    static let memoryStripHeight: CGFloat = 56

    static let ringDiameter: CGFloat = 220
    static let ringLineWidth: CGFloat = 8
    /// Smallest visible arc, in degrees, whenever something is selected.
    static let ringMinimumDegrees: Double = 4
    /// Arc shown while scanning (fraction of the circle), so the turning ring reads as motion.
    static let ringScanningFraction: Double = 0.12

    static let heroHorizontalPadding: CGFloat = 40
    static let heroButtonTopSpacing: CGFloat = 34
    static let heroSecondaryTopSpacing: CGFloat = 12

    static let rowHeight: CGFloat = 44
    static let rowHorizontalPadding: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let rowIconWidth: CGFloat = 18
    static let rowCornerRadius: CGFloat = 10
    /// Detail content lines up with the row title (padding + icon + spacing).
    static let detailIndent: CGFloat = rowHorizontalPadding + rowIconWidth + rowSpacing
    static let detailItemHeight: CGFloat = 24

    static let selectionDotSize: CGFloat = 18
    static let selectionDotLineWidth: CGFloat = 1.5

    static let listTopPadding: CGFloat = 40
    static let listLeadingPadding: CGFloat = 8
    static let listTrailingPadding: CGFloat = 20
    static let listBottomPadding: CGFloat = 12
    static let groupHeaderTopPadding: CGFloat = 12
    static let groupHeaderBottomPadding: CGFloat = 4

    static let memoryBarHeight: CGFloat = 4
    static let memoryStripSpacing: CGFloat = 16
    static let memoryStripPadding: CGFloat = 24
    static let smallButtonHeight: CGFloat = 28
    static let smallButtonPadding: CGFloat = 14
    static let popoverWidth: CGFloat = 300
    static let popoverPadding: CGFloat = 16

    /// Spacing scale for small gaps inside rows and the hero.
    static let space4: CGFloat = 4
    static let space6: CGFloat = 6
    static let space8: CGFloat = 8
    static let space10: CGFloat = 10
    static let space12: CGFloat = 12
    static let hairline: CGFloat = 1
    static let detailLineSpacing: CGFloat = 3
    static let popoverRowHeight: CGFloat = 32
    /// The failures list scrolls past this height.
    static let failuresMaxHeight: CGFloat = 240
    /// Extra hit area around the 18 pt selection mark.
    static let selectionMarkHitSlop: CGFloat = 6
    static let heroNumberMinimumScale: CGFloat = 0.6

    // MARK: Corners

    static let buttonCornerRadius: CGFloat = 14
    static let popoverCornerRadius: CGFloat = 22
    static let primaryButtonHeight: CGFloat = 48

    // MARK: Type

    static let heroNumber = Font.system(size: 64, weight: .semibold, design: .rounded)
    static let heroNumberTracking: CGFloat = -1.5
    static let heroUnit = Font.system(size: 13)
    static let heroCheck = Font.system(size: 52, weight: .semibold, design: .rounded)
    static let primaryButtonFont = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 13)
    static let rowIcon = Font.system(size: 15)
    static let chevron = Font.system(size: 10, weight: .semibold)
    static let size = Font.system(size: 13, design: .rounded)
    static let groupHeader = Font.system(size: 11, weight: .medium)
    static let groupHeaderTracking: CGFloat = 0.6
    static let detail = Font.system(size: 12)
    static let detailItemName = Font.system(size: 11, design: .monospaced)
    static let detailItemSize = Font.system(size: 12, design: .rounded)
    static let caption = Font.system(size: 12)
    static let marker = Font.system(size: 11)
    static let checkGlyph = Font.system(size: 9, weight: .bold)

    // MARK: Motion

    /// The one spring every motion uses: state changes, hover, the clean count-down.
    /// The only other motion is the ring's steady turn while scanning, and `fade` under Reduce Motion.
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    /// What replaces motion when Reduce Motion is on: a plain crossfade.
    static let fade = Animation.easeInOut(duration: 0.2)
    /// One turn of the ring while scanning.
    static let ringTurnDuration: Double = 2.4
    /// The clean count-down: this many spring steps, this far apart (about 1.2 s in all).
    static let cleanFlowSteps = 8
    static let cleanFlowStepInterval: Duration = .milliseconds(150)
    /// How long "Freed …" stays before returning to the list.
    static let doneHoldDuration: Duration = .seconds(2)
    static let disabledOpacity = 0.35
    static let pressedOpacity = 0.7
    static let pressedScale: CGFloat = 0.98
    static let hoverScale: CGFloat = 1.015
    /// Starting scale of the done checkmark and of a selection mark filling in.
    static let doneEntranceScale: CGFloat = 0.92
    static let markEntranceScale: CGFloat = 0.6
    /// Wait for a row to finish opening before scrolling it into view.
    static let scrollToExpandedDelay: Duration = .milliseconds(350)
    static let memoryRefreshInterval: Duration = .seconds(5)
    /// After Quit, look at the app list again this much later.
    static let quitRefreshDelay: Duration = .seconds(1)
    /// Label on the primary button while it waits (scanning, cleaning, done).
    static let primaryIdleLabel = Color.white.opacity(0.40)
    static let lockedOpacity = 0.25

    static func motion(reduced: Bool) -> Animation {
        reduced ? fade : spring
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
