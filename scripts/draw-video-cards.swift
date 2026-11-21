import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Brand-kit title cards for the demo video: 1920x1080, one centered line in SF Pro,
// brand green on cream, plus an end card with the logo lockup. One look everywhere.
// Usage: swift draw-video-cards.swift <output-folder> <path-to-ginkgo-logo.png>

let outDir = CommandLine.arguments[1]
let logoPath = CommandLine.arguments[2]
let W = 1920, H = 1080
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let green = rgb(0x1E5631), cream = rgb(0xF5F0E3), muted = rgb(0x5E7A63)

func font(_ size: CGFloat, weight: CGFloat) -> CTFont {
    let traits = [kCTFontWeightTrait: weight] as CFDictionary
    let desc = CTFontDescriptorCreateWithAttributes([kCTFontTraitsAttribute: traits] as CFDictionary)
    return CTFontCreateCopyWithAttributes(CTFontCreateUIFontForLanguage(.system, size, nil)!, size, nil, desc)
}

func drawCentered(_ text: String, in ctx: CGContext, y: CGFloat, size: CGFloat, weight: CGFloat,
                  color: CGColor, kern: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font(size, weight: weight),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): kern,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.textPosition = CGPoint(x: (CGFloat(W) - width) / 2, y: y)
    CTLineDraw(line, ctx)
}

func save(_ ctx: CGContext, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(name)")
}

func card() -> CGContext {
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(cream)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    return ctx
}

// Title cards: the headline, with an optional small line underneath.
let titles: [(file: String, headline: String, sub: String?)] = [
    ("01-waste.png", "12 million tons of furniture.", "Thrown away every year in the US. (EPA, 2018 data)"),
    ("02-measured.png", "Measured to the centimeter.", nil),
    ("03-proven.png", "A plan proven to fit.", nil),
    ("04-contrast.png", "Chatbots guess. Ginkgo checks.", nil),
    ("05-impact.png", "Wood saved. Nothing wasted.", nil),
]
for t in titles {
    let ctx = card()
    drawCentered(t.headline, in: ctx, y: t.sub == nil ? 505 : 540, size: 96, weight: 0.4, color: green, kern: -1)
    if let sub = t.sub {
        drawCentered(sub, in: ctx, y: 450, size: 36, weight: 0.0, color: muted)
    }
    save(ctx, t.file)
}

// End card: the logo lockup with the tagline below.
let endCtx = card()
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: logoPath) as CFURL, nil)!
let logo = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let side: CGFloat = 760
endCtx.interpolationQuality = .high
endCtx.draw(logo, in: CGRect(x: (CGFloat(W) - side) / 2, y: 250, width: side, height: side))
drawCentered("Measure it. Make it new.", in: endCtx, y: 235, size: 44, weight: 0.0, color: muted)
save(endCtx, "06-end.png")
