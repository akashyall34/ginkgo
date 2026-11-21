import CoreGraphics
import UIKit

/// A built-in scene with a known answer: a light 19.05 × 12 cm face, 50 cm in front
/// of the camera, on a dark background. Used by UI tests on the simulator (which
/// has no LiDAR) and as a demo mode. Launch with `-demoScene` to use it.
enum DemoScene {
    static let launchArgument = "-demoScene"
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    static let widthMeters: Float = 0.1905   // across the portrait photo
    static let heightMeters: Float = 0.12    // down the portrait photo
    static let distanceMeters: Float = 0.5

    /// Raw landscape image size and intrinsics, like a scaled-down iPhone capture.
    static let intrinsics = Intrinsics(fx: 700, fy: 700, cx: 480, cy: 360, imageWidth: 960, imageHeight: 720)

    /// The face's corners on the portrait photo (normalized, top-left origin):
    /// top-left, top-right, bottom-right, bottom-left.
    static var portraitCorners: [CGPoint] {
        // Portrait x runs along the camera's −y axis; portrait y along its +x axis.
        let halfW = widthMeters / 2, halfH = heightMeters / 2
        let camera: [SIMD3<Float>] = [
            SIMD3(-halfH, -halfW, -distanceMeters), SIMD3(-halfH, halfW, -distanceMeters),
            SIMD3(halfH, halfW, -distanceMeters), SIMD3(halfH, -halfW, -distanceMeters),
        ]
        return camera.map { p in
            let u = (intrinsics.fx * p.x / distanceMeters + intrinsics.cx) / intrinsics.imageWidth
            let v = (intrinsics.fy * -p.y / distanceMeters + intrinsics.cy) / intrinsics.imageHeight
            // Inverse of Geometry.rawImagePoint(fromPortrait:): raw (u, v) → portrait (1 − v, u).
            return CGPoint(x: CGFloat(1 - v), y: CGFloat(u))
        }
    }

    static func frame() -> CapturedFrame? {
        let size = CGSize(width: 720, height: 960) // portrait
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1))
        let pts = portraitCorners.map { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) } // CG origin is bottom-left
        ctx.addLines(between: pts)
        ctx.closePath()
        ctx.fillPath()
        guard let image = ctx.makeImage() else { return nil }

        let w = 192, h = 144
        guard let snapshot = DepthSnapshot(width: w, height: h,
                                           depth: Array(repeating: distanceMeters, count: w * h),
                                           confidence: Array(repeating: 2, count: w * h),
                                           intrinsics: intrinsics),
              let overlay = UIImage.confidenceOverlay(for: snapshot) else { return nil }
        return CapturedFrame(image: UIImage(cgImage: image), confidenceOverlay: overlay, snapshot: snapshot)
    }
}
