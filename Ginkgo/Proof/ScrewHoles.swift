import CoreGraphics
import GinkgoCore

/// Screw holes tapped on a drawing of a panel become keep-out zones the validator never cuts through.
/// Panel rectangles start at the panel's bottom-left in mm; the drawing is tapped top-left, 0...1.
enum ScrewHoles {
    /// A hole plus clearance around it: the size of each keep-out zone.
    static let sizeMm = 20.0

    /// The keep-out for a tap at `point` (0...1, top-left origin), kept inside the panel.
    static func keepOut(at point: CGPoint, on part: Part) -> Rect {
        let half = sizeMm / 2
        let centerX = min(max(Double(point.x) * part.widthMm, half), part.widthMm - half)
        let centerY = min(max((1 - Double(point.y)) * part.heightMm, half), part.heightMm - half)
        return Rect(heightMm: sizeMm, widthMm: sizeMm, xMm: centerX - half, yMm: centerY - half)
    }

    /// Where a keep-out's center sits on the drawing, 0...1, top-left origin.
    static func point(of hole: Rect, on part: Part) -> CGPoint {
        CGPoint(x: (hole.xMm + hole.widthMm / 2) / part.widthMm, y: 1 - (hole.yMm + hole.heightMm / 2) / part.heightMm)
    }

    /// Tapping on an existing hole removes it; anywhere else adds one.
    static func toggling(at point: CGPoint, on part: Part) -> Part {
        let tapped = keepOut(at: point, on: part)
        let hit = part.keepOuts.firstIndex { abs($0.xMm - tapped.xMm) < sizeMm && abs($0.yMm - tapped.yMm) < sizeMm }
        var holes = part.keepOuts
        if let hit { holes.remove(at: hit) } else { holes.append(tapped) }
        return part.with(keepOuts: holes)
    }
}
