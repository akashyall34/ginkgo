/// One premultiplied RGBA pixel.
struct RGBA: Equatable {
    let r, g, b, a: UInt8
}

/// Colors for the confidence overlay, as premultiplied RGBA bytes.
enum ConfidenceTint {
    /// High confidence is left clear; medium is yellow; low is red.
    static func rgba(for confidence: UInt8) -> RGBA {
        switch confidence {
        case 2...: return RGBA(r: 0, g: 0, b: 0, a: 0)
        case 1: return RGBA(r: 115, g: 100, b: 0, a: 115)   // yellow at 45% opacity
        default: return RGBA(r: 140, g: 0, b: 0, a: 140)    // red at 55% opacity
        }
    }

    /// The overlay for a whole confidence map, row by row.
    static func pixels(_ confidence: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(confidence.count * 4)
        for c in confidence {
            let p = rgba(for: c)
            out.append(contentsOf: [p.r, p.g, p.b, p.a])
        }
        return out
    }
}
