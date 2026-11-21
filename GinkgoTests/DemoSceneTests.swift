import XCTest
@testable import Ginkgo

/// End to end on a scene with a known answer: real Vision detection, real plane fit.
final class DemoSceneTests: XCTestCase {
    func testCornersAreInOrderAndInsideThePhoto() {
        let c = DemoScene.portraitCorners
        XCTAssertLessThan(c[0].x, c[1].x, "Top-left is left of top-right")
        XCTAssertLessThan(c[0].y, c[3].y, "Top-left is above bottom-left")
        XCTAssertTrue(c.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        XCTAssertTrue(DetectedQuad(corners: c).isConvex)
    }

    func testExactCornersMeasureTheKnownSize() throws {
        let frame = try XCTUnwrap(DemoScene.frame())
        let r = try QuadMeasurer.measure(corners: DetectedQuad(corners: DemoScene.portraitCorners).rawCorners,
                                         in: frame.snapshot).get()
        XCTAssertEqual(r.width, DemoScene.widthMeters, accuracy: 1e-3)
        XCTAssertEqual(r.height, DemoScene.heightMeters, accuracy: 1e-3)
    }

    func testVisionFindsTheFaceAndItMeasuresWithinAMillimeter() throws {
        let frame = try XCTUnwrap(DemoScene.frame())
        let quad = try XCTUnwrap(RectangleDetector.detect(in: try XCTUnwrap(frame.image.cgImage)).first)
        let r = try QuadMeasurer.measure(corners: quad.rawCorners, in: frame.snapshot).get()
        XCTAssertEqual(r.width, DemoScene.widthMeters, accuracy: 0.001)
        XCTAssertEqual(r.height, DemoScene.heightMeters, accuracy: 0.001)
    }
}
