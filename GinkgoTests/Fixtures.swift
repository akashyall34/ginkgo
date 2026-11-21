import Foundation
@testable import Ginkgo

/// Intrinsics shaped like an iPhone's 1920×1440 capture, with round numbers so
/// expected answers can be worked out by hand.
let testIntrinsics = Intrinsics(fx: 1000, fy: 1000, cx: 960, cy: 720,
                                imageWidth: 1920, imageHeight: 1440)

/// A 192×144 depth map (the same 4:3 shape as the capture) built from a function
/// of the pixel position.
func makeSnapshot(width: Int = 192, height: Int = 144,
                  depth: (Int, Int) -> Float,
                  confidence: (Int, Int) -> UInt8 = { _, _ in 2 }) -> DepthSnapshot {
    var d: [Float] = []
    var c: [UInt8] = []
    for y in 0..<height {
        for x in 0..<width {
            d.append(depth(x, y))
            c.append(confidence(x, y))
        }
    }
    guard let snapshot = DepthSnapshot(width: width, height: height, depth: d, confidence: c, intrinsics: testIntrinsics) else {
        preconditionFailure("Test fixture built a depth map with mismatched sizes")
    }
    return snapshot
}

/// Deterministic random numbers, so noise tests give the same result every run.
struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func nextUniform() -> Float {
        // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Float(z >> 40) / Float(1 << 24)
    }

    /// Standard normal sample (Box–Muller).
    mutating func nextNormal() -> Float {
        let u1 = max(nextUniform(), .leastNonzeroMagnitude)
        let u2 = nextUniform()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// The normalized image point for a full-resolution pixel position.
func pixel(_ x: Float, _ y: Float) -> ImagePoint {
    ImagePoint(u: x / testIntrinsics.imageWidth, v: y / testIntrinsics.imageHeight)
}
