import CoreGraphics

enum ScreenMapping {
    /// The rectangle an image of `imageSize` occupies when fitted (aspect fit,
    /// centered) inside a view of `viewSize`.
    static func fittedRect(imageSize: CGSize, in viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (viewSize.width - size.width) / 2,
                      y: (viewSize.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// Converts a tap in the view to a point on the fitted image, normalized 0...1.
    /// Returns nil when the tap lands outside the image (on the letterbox bars).
    static func normalizedPoint(tap: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint? {
        let rect = fittedRect(imageSize: imageSize, in: viewSize)
        guard rect.width > 0, rect.height > 0,
              tap.x >= rect.minX, tap.x <= rect.maxX, tap.y >= rect.minY, tap.y <= rect.maxY else { return nil }
        return CGPoint(x: (tap.x - rect.minX) / rect.width, y: (tap.y - rect.minY) / rect.height)
    }

    /// The inverse: where a normalized image point appears in the view.
    static func viewPoint(normalized p: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint {
        let rect = fittedRect(imageSize: imageSize, in: viewSize)
        return CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
    }
}
