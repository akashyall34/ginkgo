import CoreGraphics
import simd

extension Polygon {
    /// True for a simple convex polygon: every turn goes the same way and the
    /// corners don't cross. Dragged corners must pass this before measuring.
    static func isConvex(_ poly: [SIMD2<Float>]) -> Bool {
        guard poly.count >= 3 else { return false }
        var sign: Float = 0
        var totalTurn: Float = 0
        for i in 0..<poly.count {
            let a = poly[i], b = poly[(i + 1) % poly.count], c = poly[(i + 2) % poly.count]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            guard abs(cross) > 1e-9 else { return false } // three corners in a line
            if sign == 0 { sign = cross } else if (cross > 0) != (sign > 0) { return false }
            let ab = simd_normalize(b - a), bc = simd_normalize(c - b)
            totalTurn += acos(max(-1, min(1, simd_dot(ab, bc))))
        }
        // A star-shaped (self-crossing) polygon turns more than once around.
        return abs(totalTurn - 2 * .pi) < 1e-3
    }
}

extension ScreenMapping {
    /// Like `normalizedPoint`, but a drag past the photo's edge sticks to the edge
    /// instead of being dropped.
    static func clampedNormalizedPoint(_ p: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint? {
        let rect = fittedRect(imageSize: imageSize, in: viewSize)
        guard rect.width > 0, rect.height > 0 else { return nil }
        return CGPoint(x: min(max((p.x - rect.minX) / rect.width, 0), 1),
                       y: min(max((p.y - rect.minY) / rect.height, 0), 1))
    }
}

extension DetectedQuad {
    /// A starting rectangle in the middle of the photo, for placing corners by hand.
    static let manualStart = DetectedQuad(corners: [
        CGPoint(x: 0.3, y: 0.35), CGPoint(x: 0.7, y: 0.35),
        CGPoint(x: 0.7, y: 0.65), CGPoint(x: 0.3, y: 0.65),
    ])

    var isConvex: Bool {
        Polygon.isConvex(corners.map { SIMD2(Float($0.x), Float($0.y)) })
    }
}

enum Loupe {
    static let size: CGFloat = 120
    static let magnification: CGFloat = 3
    /// How far above the finger the loupe floats, so the finger never covers it.
    static let lift: CGFloat = 90

    /// Offset for content of `contentSize`, scaled by `magnification` from its top-left,
    /// so that `point` (in content coordinates) sits at the loupe's center.
    static func contentOffset(for point: CGPoint) -> CGSize {
        CGSize(width: size / 2 - point.x * magnification, height: size / 2 - point.y * magnification)
    }

    /// Where to draw the loupe for a finger at `finger`, kept inside `bounds`.
    static func center(forFinger finger: CGPoint, in bounds: CGSize) -> CGPoint {
        let half = size / 2
        var y = finger.y - lift
        if y - half < 0 { y = finger.y + lift } // no room above: show it below
        return CGPoint(x: min(max(finger.x, half), bounds.width - half),
                       y: min(max(y, half), bounds.height - half))
    }
}
