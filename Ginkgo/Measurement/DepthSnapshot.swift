/// One frozen LiDAR depth frame, copied out of ARKit so the math can be tested
/// without a camera. Depth is in meters; confidence is ARKit's 0 (low), 1, 2 (high).
struct DepthSnapshot {
    let width: Int
    let height: Int
    let depth: [Float]
    let confidence: [UInt8]
    let intrinsics: Intrinsics

    /// Nil when the sizes don't agree, so a malformed camera frame is reported as
    /// unreadable instead of crashing the app.
    init?(width: Int, height: Int, depth: [Float], confidence: [UInt8], intrinsics: Intrinsics) {
        guard width > 0, height > 0, depth.count == width * height, confidence.count == width * height else {
            return nil
        }
        self.width = width
        self.height = height
        self.depth = depth
        self.confidence = confidence
        self.intrinsics = intrinsics
    }
}
