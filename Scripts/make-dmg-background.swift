// Draws the DMG window background (660 x 400 pt) at 1x and 2x.
// Usage: swift Scripts/make-dmg-background.swift <out-1x.png> <out-2x.png>
// Scripts/make-dmg.sh combines them into one HiDPI TIFF.
// Layout must match make-dmg.sh: app icon centred at (170, 200), Applications at (490, 200), icon size 128.
import AppKit
import CoreGraphics

let width: CGFloat = 660
let height: CGFloat = 400
let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: make-dmg-background.swift <1x.png> <2x.png>") }

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let background: UInt32 = 0x0B0D12
let accentStart: UInt32 = 0x5EF2C4
let accentEnd: UInt32 = 0x3AA8FF
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func render(scale: CGFloat, to path: String) {
    let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    // Core Graphics origin is bottom-left; Finder coordinates are top-left. Convert y with `height - y`.

    ctx.setFillColor(color(background))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Soft accent glow behind the app icon, same mood as the app window.
    let glow = CGGradient(colorsSpace: space,
                          colors: [color(accentStart, alpha: 0.16), color(accentStart, alpha: 0)] as CFArray,
                          locations: [0, 1])!
    let glowCenter = CGPoint(x: 170, y: height - 200)
    ctx.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: 260, options: [])

    // Arrow from the app to Applications: gradient shaft with a rounded chevron head.
    let y = height - 200
    let shaft = CGMutablePath()
    shaft.move(to: CGPoint(x: 268, y: y))
    shaft.addLine(to: CGPoint(x: 384, y: y))
    shaft.move(to: CGPoint(x: 368, y: y + 14))
    shaft.addLine(to: CGPoint(x: 386, y: y))
    shaft.addLine(to: CGPoint(x: 368, y: y - 14))
    let stroked = shaft.copy(strokingWithWidth: 5, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.saveGState()
    ctx.addPath(stroked)
    ctx.clip()
    let accent = CGGradient(colorsSpace: space, colors: [color(accentStart), color(accentEnd)] as CFArray,
                            locations: [0, 1])!
    ctx.drawLinearGradient(accent, start: CGPoint(x: 268, y: y), end: CGPoint(x: 388, y: y), options: [])
    ctx.restoreGState()

    // Finder draws icon labels in dark text over a background picture, so give each label a light chip.
    for (centerX, labelWidth) in [(CGFloat(170), CGFloat(112)), (CGFloat(490), CGFloat(104))] {
        let chip = CGRect(x: centerX - labelWidth / 2, y: height - 283 - 11, width: labelWidth, height: 22)
        ctx.addPath(CGPath(roundedRect: chip, cornerWidth: 11, cornerHeight: 11, transform: nil))
        ctx.setFillColor(color(0xFFFFFF, alpha: 0.88))
        ctx.fillPath()
    }

    // Captions.
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ns
    func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, centerY: CGFloat) {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? font
        let string = NSAttributedString(string: text, attributes: [
            .font: rounded,
            .foregroundColor: NSColor(white: 1, alpha: alpha),
            .kern: 0.2,
        ])
        let bounds = string.size()
        string.draw(at: NSPoint(x: (width - bounds.width) / 2, y: height - centerY - bounds.height / 2))
    }
    draw("Drag FreeMyMacOS into Applications", size: 15, weight: .medium, alpha: 0.72, centerY: 318)
    draw("Free · open source · no network access", size: 12, weight: .regular, alpha: 0.32, centerY: 344)
    NSGraphicsContext.restoreGraphicsState()

    let image = ctx.makeImage()!
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

render(scale: 1, to: args[1])
render(scale: 2, to: args[2])
print("Wrote \(args[1]) and \(args[2])")
