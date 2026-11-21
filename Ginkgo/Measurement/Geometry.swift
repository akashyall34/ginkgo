import simd

/// Camera intrinsics for the full-resolution captured image, in pixels.
struct Intrinsics: Equatable {
    var fx: Float
    var fy: Float
    var cx: Float
    var cy: Float
    /// Size of the image these intrinsics belong to, in pixels.
    var imageWidth: Float
    var imageHeight: Float
}

/// A point in the raw camera image, normalized to 0...1 (u right, v down).
/// The raw image is landscape: the sensor's native orientation.
struct ImagePoint: Equatable {
    var u: Float
    var v: Float

    var isInside: Bool { (0...1).contains(u) && (0...1).contains(v) }
}

enum Geometry {
    /// Maps a point on the portrait display of the camera image (normalized 0...1,
    /// x right, y down) to the raw landscape image. The portrait display is the raw
    /// image rotated 90° clockwise, which is how the back camera appears upright.
    static func rawImagePoint(fromPortrait x: Float, _ y: Float) -> ImagePoint {
        ImagePoint(u: y, v: 1 - x)
    }

    /// Back-projects an image point at a given depth into camera space, in meters.
    /// Uses ARKit's camera convention: x right, y up, the camera looks down -z.
    static func unproject(_ p: ImagePoint, depth: Float, intrinsics k: Intrinsics) -> SIMD3<Float> {
        let px = p.u * k.imageWidth
        let py = p.v * k.imageHeight
        let x = (px - k.cx) / k.fx * depth
        let y = (py - k.cy) / k.fy * depth
        // Image y grows downward and the camera looks down -z, so flip y and z.
        return SIMD3(x, -y, -depth)
    }
}
