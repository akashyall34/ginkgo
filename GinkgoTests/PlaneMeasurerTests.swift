import XCTest
import simd
@testable import Ginkgo

final class PlaneMeasurerTests: XCTestCase {
    /// Depth map of a single plane, as LiDAR would see it.
    private func planeSnapshot(_ plane: Plane,
                               depthOverride: (Int, Int) -> Float? = { _, _ in nil },
                               confidence: @escaping (Int, Int) -> UInt8 = { _, _ in 2 }) -> DepthSnapshot {
        makeSnapshot(depth: { x, y in
            if let d = depthOverride(x, y) { return d }
            let p = ImagePoint(u: (Float(x) + 0.5) / 192, v: (Float(y) + 0.5) / 144)
            let ray = Geometry.unproject(p, depth: 1, intrinsics: testIntrinsics)
            return plane.hit(direction: ray) ?? 0
        }, confidence: confidence)
    }

    /// Projects a camera-space point into the image (the inverse of unproject).
    private func project(_ p: SIMD3<Float>) -> ImagePoint {
        let k = testIntrinsics
        let depth = -p.z
        return ImagePoint(u: (k.fx * p.x / depth + k.cx) / k.imageWidth,
                          v: (k.fy * -p.y / depth + k.cy) / k.imageHeight)
    }

    private let wall = Plane(normal: SIMD3(0, 0, 1), offset: 1) // facing the camera, 1 m away

    // The bug you hit on the phone: low confidence right where you tap.
    func testMeasuresEdgesEvenWhenTheEdgeDepthIsUnreliable() throws {
        // Columns 72–80 and 112–120 (around both taps) are low confidence.
        let snap = planeSnapshot(wall, confidence: { x, _ in (72...80).contains(x) || (112...120).contains(x) ? 0 : 2 })
        let a = pixel(760, 720), b = pixel(1160, 720)

        // The plane is fitted to the reliable surface between the taps, so the
        // unreliable depth right at each tap doesn't matter.
        let r = try PlaneMeasurer.distance(from: a, to: b, in: snap).get()
        XCTAssertEqual(r.meters, 0.4, accuracy: 1e-3)
    }

    func testTiltedTableSeenFromAbove() throws {
        // A table 50 cm below the camera, tilted away from it.
        let normal = simd_normalize(SIMD3<Float>(0.05, 1, 0.4))
        let anchor = SIMD3<Float>(0, -0.5, -0.9)
        let table = Plane(normal: normal, offset: -simd_dot(normal, anchor))

        // Two real points 30 cm apart on the table.
        let side = simd_normalize(simd_cross(normal, SIMD3(0, 0, 1)))
        let p1 = anchor - side * 0.15, p2 = anchor + side * 0.15
        XCTAssertEqual(table.distance(to: p1), 0, accuracy: 1e-6)

        let r = try PlaneMeasurer.distance(from: project(p1), to: project(p2), in: planeSnapshot(table)).get()
        XCTAssertEqual(r.meters, 0.30, accuracy: 1e-3)
    }

    func testBackgroundClutterIsIgnored() throws {
        // Every fourth pixel sees a wall 3 m behind instead of the surface.
        let snap = planeSnapshot(wall, depthOverride: { x, y in (x + y) % 4 == 0 ? 3 : nil })
        let r = try PlaneMeasurer.distance(from: pixel(760, 720), to: pixel(1160, 720), in: snap).get()
        XCTAssertEqual(r.meters, 0.4, accuracy: 1e-3)
    }

    func testSensorNoiseAveragesOut() throws {
        // 5 mm of random depth noise on every pixel.
        var gen = SeededGenerator(seed: 3)
        let noisy = makeSnapshot(depth: { _, _ in 1 + 0.005 * gen.nextNormal() })
        let r = try PlaneMeasurer.distance(from: pixel(760, 720), to: pixel(1160, 720), in: noisy).get()
        XCTAssertEqual(r.meters, 0.4, accuracy: 0.003)
        XCTAssertGreaterThan(r.uncertainty, 0)
        XCTAssertLessThan(r.uncertainty, 0.02)
    }

    func testGoodReadingReportsDiagnostics() throws {
        let r = try PlaneMeasurer.distance(from: pixel(760, 720), to: pixel(1160, 720), in: planeSnapshot(wall)).get()
        XCTAssertGreaterThan(r.surfacePoints, 400)
        XCTAssertEqual(r.fitNoise, 0, accuracy: 1e-4)
        XCTAssertLessThan(r.viewAngleDegrees, 15, "Wall faces the camera, so the view is nearly straight on")
    }

    // The 24.0 ± 11.2 cm case: never show a number that unsure.
    func testVeryNoisySurfaceIsRefusedNotReported() {
        var gen = SeededGenerator(seed: 11)
        // 2 cm of noise: far worse than LiDAR on a good surface.
        let snap = makeSnapshot(depth: { _, _ in 1 + 0.02 * gen.nextNormal() })
        XCTAssertEqual(PlaneMeasurer.distance(from: pixel(760, 720), to: pixel(1160, 720), in: snap),
                       .failure(.noFlatSurface))
    }

    func testStripAcrossTwoSurfacesIsRefused() {
        // Top half of the strip sees a box top at 1 m, bottom half the floor at 1.3 m.
        let snap = makeSnapshot(depth: { _, y in y < 72 ? 1 : 1.3 })
        XCTAssertEqual(PlaneMeasurer.distance(from: pixel(760, 720), to: pixel(1160, 720), in: snap),
                       .failure(.noFlatSurface))
    }

    // MARK: assess

    func testAssessStraightOnLowNoiseIsAccepted() throws {
        let q = try PlaneMeasurer.assess(noise: 0.002, cosA: 1, cosB: 1).get()
        XCTAssertEqual(q.uncertainty, 0.002 * Float(2).squareRoot(), accuracy: 1e-6)
        XCTAssertEqual(q.angleDegrees, 0, accuracy: 1e-3)
    }

    func testAssessAngledViewInflatesUncertainty() throws {
        // At 60° (cos 0.5), each end's error doubles.
        let q = try PlaneMeasurer.assess(noise: 0.002, cosA: 0.5, cosB: 0.5).get()
        XCTAssertEqual(q.uncertainty, 0.004 * Float(2).squareRoot(), accuracy: 1e-6)
        XCTAssertEqual(q.angleDegrees, 60, accuracy: 0.01)
    }

    func testAssessRefusesOverOneCentimeter() {
        // 6 mm noise at 60°: ± would be 1.7 cm.
        guard case .failure(.tooUncertain(let u)) = PlaneMeasurer.assess(noise: 0.006, cosA: 0.5, cosB: 0.5) else {
            return XCTFail("Expected refusal")
        }
        XCTAssertEqual(u, 0.012 * Float(2).squareRoot(), accuracy: 1e-6)
    }

    func testAssessRefusesEdgeOnUsingTheWorseTap() {
        // One tap straight on, the other at 80°: the worse one decides.
        let cos80 = Float(cos(80 * Double.pi / 180))
        guard case .failure(.tooShallow(let d)) = PlaneMeasurer.assess(noise: 0, cosA: 1, cosB: cos80) else {
            return XCTFail("Expected refusal")
        }
        XCTAssertEqual(d, 80, accuracy: 0.01)
    }

    func testAssessAcceptsExactlyAtTheLimits() throws {
        let cos70 = Float(cos(70 * Double.pi / 180))
        XCTAssertNoThrow(try PlaneMeasurer.assess(noise: 0, cosA: cos70 + 1e-6, cosB: 1).get())
        let atLimit = PlaneMeasurer.maxUncertainty / Float(2).squareRoot()
        XCTAssertNoThrow(try PlaneMeasurer.assess(noise: atLimit * 0.999, cosA: 1, cosB: 1).get())
    }

    func testSurfaceSeenNearlyEdgeOnIsRefused() {
        // A floor 30 cm below the camera, seen at a grazing angle near the horizon.
        let floor = Plane(normal: simd_normalize(SIMD3<Float>(0, 1, 0.05)), offset: 0.3)
        let snap = planeSnapshot(floor)
        let a = pixel(760, 900), b = pixel(1160, 900)
        guard case .failure(.tooShallow(let degrees)) = PlaneMeasurer.distance(from: a, to: b, in: snap) else {
            return XCTFail("Expected a grazing view to be refused")
        }
        XCTAssertGreaterThan(degrees, PlaneMeasurer.maxViewAngleDegrees)
    }

    func testModerateTiltIsStillAccepted() throws {
        // A surface tilted 45° from facing the camera is fine to measure.
        let normal = simd_normalize(SIMD3<Float>(0, 1, 1))
        let anchor = SIMD3<Float>(0, -0.3, -0.8)
        let plane = Plane(normal: normal, offset: -simd_dot(normal, anchor))
        let p1 = anchor + SIMD3(-0.1, 0, 0), p2 = anchor + SIMD3(0.1, 0, 0)
        let r = try PlaneMeasurer.distance(from: project(p1), to: project(p2), in: planeSnapshot(plane)).get()
        XCTAssertEqual(r.meters, 0.2, accuracy: 1e-3)
        XCTAssertLessThan(r.viewAngleDegrees, PlaneMeasurer.maxViewAngleDegrees)
    }

    func testNoReliableSurfaceIsAnError() {
        let snap = planeSnapshot(wall, confidence: { _, _ in 1 })
        XCTAssertEqual(PlaneMeasurer.distance(from: pixel(760, 720), to: pixel(1160, 720), in: snap),
                       .failure(.notEnoughSurface(usable: 0, needed: 30)))
    }

    func testSamePointAndOutsideAreRejected() {
        let snap = planeSnapshot(wall)
        XCTAssertEqual(PlaneMeasurer.distance(from: pixel(960, 720), to: pixel(960, 720), in: snap), .failure(.samePoint))
        XCTAssertEqual(PlaneMeasurer.distance(from: pixel(960, 720), to: ImagePoint(u: 1.3, v: 0.5), in: snap),
                       .failure(.outsideImage))
    }

    func testStripOnlySamplesNearTheLine() {
        // Only pixels within the strip around a horizontal line are used.
        let snap = planeSnapshot(wall)
        let pts = PlaneMeasurer.surfacePoints(between: pixel(760, 720), and: pixel(1160, 720), in: snap)
        XCTAssertGreaterThan(pts.count, 400)
        XCTAssertLessThan(pts.count, 700)
        for p in pts { XCTAssertLessThan(abs(p.y), 0.07, "Point too far from the line between taps") }
    }
}
