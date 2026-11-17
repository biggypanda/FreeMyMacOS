// Draws the 1024 px app icon source: a dark rounded square with the accent gradient ring.
// Usage: swift Scripts/make-icon.swift <output.png>
// Scripts/make-icon.sh turns the PNG into Support/AppIcon.icns.
import AppKit
import CoreGraphics

let size = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let background: UInt32 = 0x0B0D12
let accentStart: UInt32 = 0x5EF2C4
let accentEnd: UInt32 = 0x3AA8FF

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("could not create context") }

let canvas = CGFloat(size)
// macOS icon grid: the rounded square is 824 px inside a 1024 px canvas, corner radius ~185.
let tileInset: CGFloat = 100
let tile = CGRect(x: tileInset, y: tileInset, width: canvas - 2 * tileInset, height: canvas - 2 * tileInset)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Soft drop shadow under the tile, as system icons have.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, alpha: 0.45))
ctx.addPath(tilePath)
ctx.setFillColor(color(background))
ctx.fillPath()
ctx.restoreGState()

// Tile fill plus a faint accent glow from the upper left (as in the app's background).
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
ctx.setFillColor(color(background))
ctx.fill(tile)
let glow = CGGradient(
    colorsSpace: space,
    colors: [color(accentStart, alpha: 0.10), color(accentStart, alpha: 0)] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: tile.minX + tile.width * 0.3, y: tile.maxY - tile.height * 0.3), startRadius: 0,
    endCenter: CGPoint(x: tile.minX + tile.width * 0.3, y: tile.maxY - tile.height * 0.3), endRadius: tile.width * 0.8,
    options: []
)
// Hairline edge so the tile reads on a dark Dock.
ctx.addPath(tilePath)
ctx.setStrokeColor(color(0xFFFFFF, alpha: 0.08))
ctx.setLineWidth(4)
ctx.strokePath()
ctx.restoreGState()

// The ring: a faint full track, then the accent arc with round caps.
let center = CGPoint(x: canvas / 2, y: canvas / 2)
let radius: CGFloat = 250
let lineWidth: CGFloat = 64

ctx.setLineWidth(lineWidth)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.setStrokeColor(color(0xFFFFFF, alpha: 0.08))
ctx.strokePath()

// Arc from the top, clockwise, about 300 degrees, filled with a linear gradient
// (top-left accentStart to bottom-right accentEnd), matching Theme.accentGradient.
let startAngle = CGFloat.pi / 2
let sweep = CGFloat.pi * 2 * (300.0 / 360.0)
let arc = CGMutablePath()
arc.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle - sweep, clockwise: true)
let stroked = arc.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)

ctx.saveGState()
ctx.addPath(stroked)
ctx.clip()
let accent = CGGradient(
    colorsSpace: space, colors: [color(accentStart), color(accentEnd)] as CFArray, locations: [0, 1]
)!
let box = CGRect(x: center.x - radius - lineWidth, y: center.y - radius - lineWidth,
                 width: 2 * (radius + lineWidth), height: 2 * (radius + lineWidth))
ctx.drawLinearGradient(
    accent,
    start: CGPoint(x: box.minX, y: box.maxY),
    end: CGPoint(x: box.maxX, y: box.minY),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("could not render") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("could not encode PNG") }
try data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
