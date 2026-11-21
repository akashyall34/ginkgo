import CoreGraphics

/// Pinch zoom and pan applied to the frozen photo: scaled about the view's
/// center, then shifted by `offset` (the same order as SwiftUI's
/// `.scaleEffect(scale).offset(offset)`).
struct ZoomTransform: Equatable {
    static let maxScale: CGFloat = 8

    var scale: CGFloat = 1
    var offset: CGSize = .zero

    /// Where a point on the unzoomed content appears on screen.
    func toView(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: (p.x - size.width / 2) * scale + size.width / 2 + offset.width,
                y: (p.y - size.height / 2) * scale + size.height / 2 + offset.height)
    }

    /// Which point on the unzoomed content a screen tap lands on.
    func toContent(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: (p.x - size.width / 2 - offset.width) / scale + size.width / 2,
                y: (p.y - size.height / 2 - offset.height) / scale + size.height / 2)
    }

    /// Keeps the scale within 1...maxScale and the content covering the view,
    /// so it can't be zoomed out past normal or dragged off screen.
    func clamped(in size: CGSize) -> ZoomTransform {
        let s = min(max(scale, 1), Self.maxScale)
        let maxX = size.width * (s - 1) / 2
        let maxY = size.height * (s - 1) / 2
        return ZoomTransform(scale: s,
                             offset: CGSize(width: min(max(offset.width, -maxX), maxX),
                                            height: min(max(offset.height, -maxY), maxY)))
    }
}
