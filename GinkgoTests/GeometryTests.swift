import XCTest
import simd
@testable import Ginkgo

final class GeometryTests: XCTestCase {
    // MARK: unproject

    func testPrincipalPointLiesStraightAhead() {
        let p = Geometry.unproject(pixel(960, 720), depth: 1.5, intrinsics: testIntrinsics)
        XCTAssertEqual(p, SIMD3(0, 0, -1.5))
    }

    func testOneFocalLengthRightIsOneDepthRight() {
        // 1000 px right of center with fx = 1000 → x equals the depth.
        let p = Geometry.unproject(pixel(1960, 720), depth: 2, intrinsics: testIntrinsics)
        XCTAssertEqual(p.x, 2, accuracy: 1e-5)
        XCTAssertEqual(p.y, 0, accuracy: 1e-5)
        XCTAssertEqual(p.z, -2, accuracy: 1e-5)
    }

    func testBelowCenterInImageIsDownInCameraSpace() {
        // Image y grows downward; camera-space y grows upward.
        let p = Geometry.unproject(pixel(960, 1220), depth: 1, intrinsics: testIntrinsics)
        XCTAssertEqual(p.y, -0.5, accuracy: 1e-5)
    }

    func testLeftOfCenterIsNegativeX() {
        let p = Geometry.unproject(pixel(460, 720), depth: 1, intrinsics: testIntrinsics)
        XCTAssertEqual(p.x, -0.5, accuracy: 1e-5)
    }

    func testDepthScalesThePointAlongItsRay() {
        let near = Geometry.unproject(pixel(1300, 400), depth: 1, intrinsics: testIntrinsics)
        let far = Geometry.unproject(pixel(1300, 400), depth: 3, intrinsics: testIntrinsics)
        XCTAssertEqual(far.x, near.x * 3, accuracy: 1e-5)
        XCTAssertEqual(far.y, near.y * 3, accuracy: 1e-5)
        XCTAssertEqual(far.z, near.z * 3, accuracy: 1e-5)
    }

    // MARK: portrait display → raw image

    func testPortraitCornersMapToRawCorners() {
        // The raw landscape image is shown rotated 90° clockwise.
        XCTAssertEqual(Geometry.rawImagePoint(fromPortrait: 0, 0), ImagePoint(u: 0, v: 1)) // top-left
        XCTAssertEqual(Geometry.rawImagePoint(fromPortrait: 1, 0), ImagePoint(u: 0, v: 0)) // top-right
        XCTAssertEqual(Geometry.rawImagePoint(fromPortrait: 1, 1), ImagePoint(u: 1, v: 0)) // bottom-right
        XCTAssertEqual(Geometry.rawImagePoint(fromPortrait: 0, 1), ImagePoint(u: 1, v: 1)) // bottom-left
    }

    func testPortraitCenterMapsToRawCenter() {
        XCTAssertEqual(Geometry.rawImagePoint(fromPortrait: 0.5, 0.5), ImagePoint(u: 0.5, v: 0.5))
    }

    func testPortraitMappingKeepsDistancesOnAnAxis() {
        // Moving down the portrait screen moves right along the raw image.
        let a = Geometry.rawImagePoint(fromPortrait: 0.3, 0.2)
        let b = Geometry.rawImagePoint(fromPortrait: 0.3, 0.7)
        XCTAssertEqual(b.u - a.u, 0.5, accuracy: 1e-6)
        XCTAssertEqual(b.v, a.v)
    }

    // MARK: ImagePoint

    func testInsideIncludesEdgesAndExcludesOutside() {
        XCTAssertTrue(ImagePoint(u: 0, v: 0).isInside)
        XCTAssertTrue(ImagePoint(u: 1, v: 1).isInside)
        XCTAssertFalse(ImagePoint(u: -0.01, v: 0.5).isInside)
        XCTAssertFalse(ImagePoint(u: 0.5, v: 1.01).isInside)
        XCTAssertFalse(ImagePoint(u: .nan, v: 0.5).isInside)
    }
}
