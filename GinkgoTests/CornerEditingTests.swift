import XCTest
@testable import Ginkgo

final class CornerEditingTests: XCTestCase {
    private func poly(_ pts: [(Float, Float)]) -> [SIMD2<Float>] { pts.map { SIMD2($0.0, $0.1) } }

    // MARK: convexity

    func testRectangleAndTrapezoidAreConvex() {
        XCTAssertTrue(Polygon.isConvex(poly([(0, 0), (4, 0), (4, 2), (0, 2)])))
        XCTAssertTrue(Polygon.isConvex(poly([(1, 0), (3, 0), (4, 2), (0, 2)])), "A face seen at an angle")
        XCTAssertTrue(Polygon.isConvex(poly([(0, 2), (4, 2), (4, 0), (0, 0)])), "Either winding")
    }

    func testCrossedCornersAreRejected() {
        // Two corners dragged past each other: a bow-tie.
        XCTAssertFalse(Polygon.isConvex(poly([(0, 0), (4, 2), (4, 0), (0, 2)])))
    }

    func testDentedQuadIsRejected() {
        // One corner dragged inside the shape.
        XCTAssertFalse(Polygon.isConvex(poly([(0, 0), (4, 0), (1, 1), (0, 4)])))
    }

    func testCollapsedCornersAreRejected() {
        XCTAssertFalse(Polygon.isConvex(poly([(0, 0), (2, 0), (4, 0), (0, 2)])), "Three corners in a line")
        XCTAssertFalse(Polygon.isConvex(poly([(0, 0), (1, 1)])), "Too few corners")
    }

    func testManualStartIsAValidFace() {
        XCTAssertTrue(DetectedQuad.manualStart.isConvex)
        XCTAssertTrue(DetectedQuad.manualStart.contains(CGPoint(x: 0.5, y: 0.5)))
    }

    // MARK: dragging past the edge

    func testDragPastThePhotoEdgeSticksToTheEdge() throws {
        let image = CGSize(width: 1440, height: 1920), view = CGSize(width: 390, height: 700)
        // Photo occupies y 90...610.
        let above = try XCTUnwrap(ScreenMapping.clampedNormalizedPoint(CGPoint(x: 195, y: 10), imageSize: image, viewSize: view))
        XCTAssertEqual(above.y, 0, accuracy: 1e-9)
        let right = try XCTUnwrap(ScreenMapping.clampedNormalizedPoint(CGPoint(x: 500, y: 350), imageSize: image, viewSize: view))
        XCTAssertEqual(right.x, 1, accuracy: 1e-9)
        XCTAssertEqual(right.y, 0.5, accuracy: 1e-9)
    }

    func testClampedMatchesUnclampedInsideThePhoto() throws {
        let image = CGSize(width: 1440, height: 1920), view = CGSize(width: 390, height: 700)
        let p = CGPoint(x: 120, y: 300)
        let a = try XCTUnwrap(ScreenMapping.clampedNormalizedPoint(p, imageSize: image, viewSize: view))
        let b = try XCTUnwrap(ScreenMapping.normalizedPoint(tap: p, imageSize: image, viewSize: view))
        XCTAssertEqual(a.x, b.x, accuracy: 1e-12)
        XCTAssertEqual(a.y, b.y, accuracy: 1e-12)
    }

    // MARK: loupe

    func testLoupeCentersTheTouchedPoint() {
        // The content point, scaled by the magnification and shifted, lands at the loupe center.
        let p = CGPoint(x: 100, y: 200)
        let o = Loupe.contentOffset(for: p)
        XCTAssertEqual(p.x * Loupe.magnification + o.width, Loupe.size / 2, accuracy: 1e-9)
        XCTAssertEqual(p.y * Loupe.magnification + o.height, Loupe.size / 2, accuracy: 1e-9)
    }

    func testLoupeFloatsAboveTheFinger() {
        let c = Loupe.center(forFinger: CGPoint(x: 200, y: 400), in: CGSize(width: 390, height: 700))
        XCTAssertEqual(c, CGPoint(x: 200, y: 400 - Loupe.lift))
    }

    func testLoupeFlipsBelowNearTheTopAndStaysOnScreen() {
        let bounds = CGSize(width: 390, height: 700)
        let nearTop = Loupe.center(forFinger: CGPoint(x: 5, y: 20), in: bounds)
        XCTAssertGreaterThan(nearTop.y, 20, "No room above, so it shows below the finger")
        XCTAssertGreaterThanOrEqual(nearTop.x - Loupe.size / 2, 0, "Kept inside the left edge")
    }
}
