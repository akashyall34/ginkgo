import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Ginkgo's mark: a ginkgo leaf built from cut panels, separated by thin gaps like saw
// kerfs; the center cut opens into the leaf's notch. Drawn from exact shapes at any size.
//
// Usage:
//   swift draw-app-icon.swift icon   <output.png> <pixels>   App icon: green mark on cream
//   swift draw-app-icon.swift lockup <output.png> <pixels>   Logo + "GINKGO" wordmark on cream

let mode = CommandLine.arguments[1]
let out = CommandLine.arguments[2]
let size = Int(CommandLine.arguments[3])!

let green: UInt32 = 0x1E5631, cream: UInt32 = 0xF5F0E3
func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024) // design in a 1024-unit square

let background = cream  // green mark on cream, for the icon and the lockup alike
let ink = green
ctx.setFillColor(rgb(background))
ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

/// Draws the mark with its leaf base at `base`, scaled by `s` (1 = icon size).
func drawMark(base: CGPoint, scale s: CGFloat) {
    func polar(_ deg: CGFloat, _ r: CGFloat) -> CGPoint {
        CGPoint(x: base.x + s * r * cos(deg * .pi / 180), y: base.y + s * r * sin(deg * .pi / 180))
    }
    // Leaf: near-straight sides, rounded corners, a broad arched top meeting at the center.
    let top = CGPoint(x: base.x, y: base.y + s * 352)
    let leaf = CGMutablePath()
    leaf.move(to: base)
    leaf.addQuadCurve(to: polar(28, 330), control: polar(33, 170))
    leaf.addQuadCurve(to: polar(40, 392), control: polar(27, 392))
    leaf.addCurve(to: top, control1: polar(58, 425), control2: CGPoint(x: base.x + s * 58, y: base.y + s * 402))
    leaf.addCurve(to: polar(140, 392), control1: CGPoint(x: base.x - s * 58, y: base.y + s * 402), control2: polar(122, 425))
    leaf.addQuadCurve(to: polar(152, 330), control: polar(153, 392))
    leaf.addQuadCurve(to: base, control: polar(147, 170))
    leaf.closeSubpath()
    ctx.setFillColor(rgb(ink))
    ctx.addPath(leaf)
    ctx.fillPath()

    // Saw cuts: constant-width gaps from just above the base out through the edge,
    // so the base stays solid and every panel is cleanly separated.
    ctx.setStrokeColor(rgb(background))
    ctx.setLineCap(.butt)
    for deg in [50, 70, 110, 130] as [CGFloat] {
        ctx.setLineWidth(s * 15)
        ctx.move(to: polar(deg, 96)); ctx.addLine(to: polar(deg, 520))
        ctx.strokePath()
    }
    ctx.setLineWidth(s * 17)
    ctx.move(to: polar(90, 96)); ctx.addLine(to: polar(90, 520))
    ctx.strokePath()

    // The ginkgo notch: the center cut opens into a V at the top edge.
    ctx.setFillColor(rgb(background))
    let notch = CGMutablePath()
    notch.move(to: CGPoint(x: base.x - s * 40, y: base.y + s * 440))
    notch.addLine(to: CGPoint(x: base.x, y: base.y + s * 268))
    notch.addLine(to: CGPoint(x: base.x + s * 40, y: base.y + s * 440))
    notch.closeSubpath()
    ctx.addPath(notch)
    ctx.fillPath()

    // Stem: begins inside the solid base and curves gently down.
    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: base.x, y: base.y + s * 40))
    stem.addCurve(to: CGPoint(x: base.x + s * 36, y: base.y - s * 150),
                  control1: CGPoint(x: base.x, y: base.y - s * 70),
                  control2: CGPoint(x: base.x + s * 18, y: base.y - s * 100))
    ctx.setStrokeColor(rgb(ink))
    ctx.setLineWidth(s * 30)
    ctx.setLineCap(.round)
    ctx.addPath(stem)
    ctx.strokePath()
}

switch mode {
case "icon":
    drawMark(base: CGPoint(x: 512, y: 340), scale: 1)  // raised for optical centering
case "lockup":
    drawMark(base: CGPoint(x: 512, y: 470), scale: 0.62)
    // Wordmark: the system font, semibold, widely letterspaced, centered below the mark.
    let traits = [kCTFontWeightTrait: 0.4] as CFDictionary
    let desc = CTFontDescriptorCreateWithAttributes([kCTFontTraitsAttribute: traits] as CFDictionary)
    let base = CTFontCreateUIFontForLanguage(.system, 118, nil)!
    let font = CTFontCreateCopyWithAttributes(base, 118, nil, desc)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): rgb(ink),
        NSAttributedString.Key(kCTKernAttributeName as String): 30,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "GINKGO", attributes: attrs))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil) - 30 // drop the trailing letter space
    ctx.textPosition = CGPoint(x: 512 - width / 2, y: 175)
    CTLineDraw(line, ctx)
default:
    fatalError("mode must be icon or lockup")
}

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
