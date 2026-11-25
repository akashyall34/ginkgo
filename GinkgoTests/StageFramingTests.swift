import simd
import XCTest
@testable import Ginkgo

final class StageFramingTests: XCTestCase {
    private func pose(_ size: SIMD3<Float>, at position: SIMD3<Float>, turned degrees: Float = 0) -> PanelPose {
        PanelPose(size: size, position: position,
                  rotation: simd_quatf(angle: degrees * .pi / 180, axis: SIMD3(0, 1, 0)))
    }

    func testABuildIsDrawnTheSameSizeAcrossAndCentered() {
        let seat = pose(SIMD3(0.4, 0.3, 0.018), at: SIMD3(0, 0.45, 0))
        let leg = pose(SIMD3(0.3, 0.44, 0.018), at: SIMD3(0.19, 0.22, 0), turned: 90)
        let framing = StageFraming.fit([seat, leg])
        // Unrotated, the seat stands: x -0.2...0.2, y 0.3...0.6. The turned leg: x 0.181...0.199, y 0...0.44,
        // z -0.15...0.15. Widest: y, 0...0.6 m, centered at (0, 0.3, 0).
        XCTAssertEqual(framing.scale, StageFraming.size / 0.6, accuracy: 0.001)
        let center = SIMD3<Float>(0, 0.3, 0) * framing.scale + framing.offset
        XCTAssertEqual(simd_length(center), 0, accuracy: 0.001)
    }

    func testRotationSwapsTheExtent() {
        let turned = pose(SIMD3(0.3, 0.44, 0.018), at: .zero, turned: 90)
        XCTAssertEqual(turned.halfExtent.x, 0.009, accuracy: 0.0001)
        XCTAssertEqual(turned.halfExtent.z, 0.15, accuracy: 0.0001)
    }

    func testABigShelfAndASmallStoolFillTheSameWidth() {
        let stool = StageFraming.fit([pose(SIMD3(0.3, 0.3, 0.3), at: .zero)])
        let shelf = StageFraming.fit([pose(SIMD3(0.9, 1.8, 0.3), at: .zero)])
        XCTAssertEqual(0.3 * stool.scale, 1.8 * shelf.scale, accuracy: 0.001)
    }

    func testNothingToFrameLeavesTheSceneAlone() {
        let framing = StageFraming.fit([])
        XCTAssertEqual(framing.scale, 1)
        XCTAssertEqual(framing.offset, .zero)
    }
}
