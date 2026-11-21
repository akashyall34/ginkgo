import XCTest
import simd
@testable import Ginkgo

final class QuadMeasurerTests: XCTestCase {
    private func project(_ p: SIMD3<Float>) -> ImagePoint {
        let k = testIntrinsics
        let depth = -p.z
        return ImagePoint(u: (k.fx * p.x / depth + k.cx) / k.imageWidth,
                          v: (k.fy * -p.y / depth + k.cy) / k.imageHeight)
    }

    private func planeSnapshot(_ plane: Plane, confidence: @escaping (Int, Int) -> UInt8 = { _, _ in 2 }) -> DepthSnapshot {
        makeSnapshot(depth: { x, y in
            let p = ImagePoint(u: (Float(x) + 0.5) / 192, v: (Float(y) + 0.5) / 144)
            return plane.hit(direction: Geometry.unproject(p, depth: 1, intrinsics: testIntrinsics)) ?? 0
        }, confidence: confidence)
    }

    /// The four corners of a w × h rectangle centered at `center` on a plane, in
    /// the order top-left, top-right, bottom-right, bottom-left as the camera sees them.
    private func rectangle(center: SIMD3<Float>, along u: SIMD3<Float>, _ v: SIMD3<Float>,
                           w: Float, h: Float) -> [SIMD3<Float>] {
        [center - u * w / 2 + v * h / 2, center + u * w / 2 + v * h / 2,
         center + u * w / 2 - v * h / 2, center - u * w / 2 - v * h / 2]
    }

    // MARK: Polygon

    func testPolygonContainsInEitherWinding() {
        let square: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]
        XCTAssertTrue(Polygon.contains(square, SIMD2(0.5, 0.5)))
        XCTAssertTrue(Polygon.contains(square.reversed(), SIMD2(0.5, 0.5)))
        XCTAssertTrue(Polygon.contains(square, SIMD2(1, 0.5)), "Edges count as inside")
        XCTAssertFalse(Polygon.contains(square, SIMD2(1.01, 0.5)))
        XCTAssertFalse(Polygon.contains(square, SIMD2(-0.5, -0.5)))
    }

    func testInsetShrinksTowardCenter() {
        let square: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)]
        let inner = Polygon.inset(square, by: 0.2)
        XCTAssertEqual(inner[0], SIMD2(1, 1))
        XCTAssertEqual(inner[2], SIMD2(9, 9))
    }

    // MARK: measuring a face

    func testBoxFaceStraightOn() throws {
        // A 19.05 × 12 cm face, 50 cm away, facing the camera.
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 0.5)
        let c = rectangle(center: SIMD3(0, 0, -0.5), along: SIMD3(1, 0, 0), SIMD3(0, 1, 0), w: 0.1905, h: 0.12)
        let r = try QuadMeasurer.measure(corners: c.map(project), in: planeSnapshot(wall)).get()
        XCTAssertEqual(r.width, 0.1905, accuracy: 1e-3)
        XCTAssertEqual(r.height, 0.12, accuracy: 1e-3)
        XCTAssertEqual(r.uncertainty, 0, accuracy: 1e-3)
    }

    func testBoxTopSeenFromAboveAtAnAngle() throws {
        // The top of a box on the floor, seen from above and in front (about 40°).
        let normal = simd_normalize(SIMD3<Float>(0, 1, 0.85))
        let center = SIMD3<Float>(0, -0.2, -0.6)
        let plane = Plane(normal: normal, offset: -simd_dot(normal, center))
        let u = SIMD3<Float>(1, 0, 0)
        let v = simd_normalize(simd_cross(normal, u))
        let c = rectangle(center: center, along: u, v, w: 0.1905, h: 0.12)
        let corners = c.map(project)
        XCTAssertTrue(corners.allSatisfy(\.isInside), "Test setup: the whole face must be in frame")
        let r = try QuadMeasurer.measure(corners: corners, in: planeSnapshot(plane)).get()
        XCTAssertEqual(r.width, 0.1905, accuracy: 1e-3)
        XCTAssertEqual(r.height, 0.12, accuracy: 1e-3)
        XCTAssertGreaterThan(r.viewAngleDegrees, 25)
    }

    func testUnreliableEdgesDoNotMatterBecauseTheBorderIsSkipped() throws {
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 0.5)
        let c = rectangle(center: SIMD3(0, 0, -0.5), along: SIMD3(1, 0, 0), SIMD3(0, 1, 0), w: 0.2, h: 0.15)
        let corners = c.map(project)
        // Low confidence within 4 depth pixels of the face's border.
        let xs = corners.map { $0.u * 192 }, ys = corners.map { $0.v * 144 }
        let snap = planeSnapshot(wall, confidence: { x, y in
            let fx = Float(x), fy = Float(y)
            let nearX = xs.contains { abs($0 - fx) < 4 }, nearY = ys.contains { abs($0 - fy) < 4 }
            return nearX || nearY ? 0 : 2
        })
        let r = try QuadMeasurer.measure(corners: corners, in: snap).get()
        XCTAssertEqual(r.width, 0.2, accuracy: 1e-3)
    }

    func testCornersThatAreNotARectangleRaiseTheUncertainty() {
        // A bad detection: one corner 3 cm off, so opposite sides disagree.
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 0.5)
        var c = rectangle(center: SIMD3(0, 0, -0.5), along: SIMD3(1, 0, 0), SIMD3(0, 1, 0), w: 0.2, h: 0.15)
        c[1].x += 0.03
        guard case .failure(.tooUncertain(let u)) = QuadMeasurer.measure(corners: c.map(project), in: planeSnapshot(wall)) else {
            return XCTFail("A distorted quad should be refused")
        }
        XCTAssertGreaterThan(u, 0.01)
    }

    func testSmallMismatchIsReportedInTheUncertainty() throws {
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 0.5)
        var c = rectangle(center: SIMD3(0, 0, -0.5), along: SIMD3(1, 0, 0), SIMD3(0, 1, 0), w: 0.2, h: 0.15)
        c[1].x += 0.004 // top edge 4 mm longer than bottom
        let r = try QuadMeasurer.measure(corners: c.map(project), in: planeSnapshot(wall)).get()
        XCTAssertEqual(r.uncertainty, 0.002, accuracy: 3e-4)
        XCTAssertEqual(r.width, 0.202, accuracy: 1e-3)
    }

    func testEdgeGapsAreReportedPerPair() throws {
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 0.5)
        var c = rectangle(center: SIMD3(0, 0, -0.5), along: SIMD3(1, 0, 0), SIMD3(0, 1, 0), w: 0.2, h: 0.15)
        c[1].x += 0.006 // top edge 6 mm longer than the bottom
        let r = try QuadMeasurer.measure(corners: c.map(project), in: planeSnapshot(wall)).get()
        XCTAssertEqual(r.widthEdgeGap, 0.006, accuracy: 5e-4)
        XCTAssertEqual(r.heightEdgeGap, 0, accuracy: 5e-4, "Moving a top corner sideways keeps the sides equal")
    }

    func testMisplacedCornerHintOnlyAboveOneCentimeter() {
        func result(_ w: Float, _ h: Float) -> QuadResult {
            QuadResult(width: 0.2, height: 0.1, uncertainty: 0.005, surfacePoints: 400, viewAngleDegrees: 10,
                       widthEdgeGap: w, heightEdgeGap: h)
        }
        XCTAssertNil(result(0.004, 0.009).misplacedCornerHint, "Small gaps are normal noise")
        XCTAssertNil(result(0.01, 0.01).misplacedCornerHint, "Exactly at the limit is still fine")
        XCTAssertEqual(result(0.016, 0.002).misplacedCornerHint,
                       "The top and bottom edges differ by 1.6 cm. A corner is probably off: drag the corners onto the face's corners.")
        XCTAssertEqual(result(0.003, 0.021).misplacedCornerHint?.hasPrefix("The left and right edges differ by 2.1 cm"), true)
    }

    func testCornerOutsideTheImageIsRejected() {
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 0.5)
        let corners = [ImagePoint(u: 0.4, v: 0.4), ImagePoint(u: 1.2, v: 0.4),
                       ImagePoint(u: 0.6, v: 0.6), ImagePoint(u: 0.4, v: 0.6)]
        XCTAssertEqual(QuadMeasurer.measure(corners: corners, in: planeSnapshot(wall)), .failure(.outsideImage))
    }

    func testTooSmallAFaceHasTooFewPoints() {
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 0.5)
        let c = rectangle(center: SIMD3(0, 0, -0.5), along: SIMD3(1, 0, 0), SIMD3(0, 1, 0), w: 0.01, h: 0.01)
        guard case .failure(.notEnoughSurface) = QuadMeasurer.measure(corners: c.map(project), in: planeSnapshot(wall)) else {
            return XCTFail("A 1 cm face has too few depth pixels to fit")
        }
    }
}
