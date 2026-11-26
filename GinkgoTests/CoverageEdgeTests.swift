import simd
import UIKit
import XCTest
@testable import Ginkgo
import GinkgoCore

/// The unusual inputs the app's logic still has to handle: degenerate geometry, failed saves, unknown ids and empty
/// lists. Each test says what should happen, and together they keep every line of the logic exercised.
@MainActor
final class CoverageEdgeTests: XCTestCase {
    // MARK: - Synthetic depth

    /// Depth of the flat plane n·P = d0, built so each depth pixel stands for a 10×10 block of the capture.
    private func plane(normal n: SIMD3<Float>, d0: Float = 1) -> DepthSnapshot {
        makeSnapshot(depth: { x, y in
            let ray = SIMD3<Float>((Float(x) * 10 + 5 - 960) / 1000, (Float(y) * 10 + 5 - 720) / 1000, 1)
            let denominator = simd_dot(n, ray)
            return denominator > 0.0001 ? d0 / denominator : .nan
        })
    }

    private func corners(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float) -> [ImagePoint] {
        [pixel(x0, y0), pixel(x1, y0), pixel(x1, y1), pixel(x0, y1)]
    }

    // MARK: - Measuring a face

    func testAFaceNeedsFourCorners() {
        let result = QuadMeasurer.measure(corners: Array(corners(600, 400, 1300, 1000).prefix(3)), in: plane(normal: [0, 0, 1]))
        XCTAssertEqual(result, .failure(.needsFourCorners))
        XCTAssertEqual(PlaneMeasureError.needsFourCorners.explanation, "A face needs four corners.")
    }

    func testRandomDepthHasNoFlatSurface() {
        var generator = SeededGenerator(seed: 7)
        let noise = makeSnapshot(depth: { _, _ in 1 + generator.nextUniform() })
        XCTAssertEqual(QuadMeasurer.measure(corners: corners(600, 400, 1300, 1000), in: noise), .failure(.noFlatSurface))
    }

    func testASurfaceSeenAlmostEdgeOnIsRefused() {
        let steep = plane(normal: [sin(85 * .pi / 180), 0, cos(85 * .pi / 180)])
        guard case .failure(let error) = QuadMeasurer.measure(corners: corners(1000, 500, 1100, 900), in: steep),
              case .tooShallow = error else { return XCTFail("Expected tooShallow") }
    }

    func testALineOfSightAlongTheSurfaceMissesIt() {
        let wall = plane(normal: [1, 0, 0], d0: 0.1)
        XCTAssertEqual(QuadMeasurer.measure(corners: corners(960, 400, 1400, 1000), in: wall), .failure(.missesSurface(point: 1)))
        XCTAssertEqual(PlaneMeasurer.distance(from: pixel(960, 720), to: pixel(1400, 720), in: wall),
                       .failure(.missesSurface(point: 1)))
        XCTAssertEqual(PlaneMeasurer.distance(from: pixel(1400, 720), to: pixel(960, 720), in: wall),
                       .failure(.missesSurface(point: 2)))
    }

    func testNoSurfacePointsFromAnEmptyOrOffImagePolygon() {
        let flat = plane(normal: [0, 0, 1])
        XCTAssertEqual(QuadMeasurer.surfacePoints(inside: [], in: flat), [])
        XCTAssertEqual(QuadMeasurer.surfacePoints(inside: [SIMD2(500, 500), SIMD2(600, 500), SIMD2(600, 600)], in: flat), [])
        XCTAssertFalse(Polygon.contains([SIMD2(0, 0), SIMD2(1, 1)], SIMD2(0.5, 0.5)), "Two points enclose nothing")
    }

    func testTapsOutsideTheDepthMapGiveNoStripAndOneRepeatedTapStillSamples() {
        let flat = plane(normal: [0, 0, 1])
        XCTAssertEqual(PlaneMeasurer.surfacePoints(between: ImagePoint(u: 3, v: 3), and: ImagePoint(u: 4, v: 4), in: flat), [])
        let same = pixel(960, 720)
        XCTAssertFalse(PlaneMeasurer.surfacePoints(between: same, and: same, in: flat).isEmpty)
    }

    func testADistanceInCentimetersAndItsUncertainty() {
        let result = DistanceResult(meters: 0.5, uncertainty: 0.002, surfacePoints: 10, fitNoise: 0, viewAngleDegrees: 0)
        XCTAssertEqual(result.centimeters, 50, accuracy: 0.001)
        XCTAssertEqual(result.uncertaintyCentimeters, 0.2, accuracy: 0.001)
    }

    // MARK: - Plane fitting

    func testTooFewOrBrokenPointsMakeNoPlane() {
        XCTAssertNil(Plane.leastSquares([]))
        XCTAssertNil(Plane.leastSquares([SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(.nan, 1, 0)]), "Not-a-number points can't fit")
        XCTAssertNil(RansacPlaneFitter().fit([SIMD3(0, 0, 0), SIMD3(1, 1, 1)]))
        XCTAssertNil(RansacPlaneFitter().fit(Array(repeating: SIMD3<Float>(1, 1, 1), count: 20)), "All the same point")
    }

    func testTheSmallestSpreadAxisIsFoundWhicheverAxisItIs() {
        func axis(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> {
            let v = SymmetricEigen.smallestEigenvector(simd_float3x3(diagonal: SIMD3(x, y, z)))
            return SIMD3(abs(v.x), abs(v.y), abs(v.z))
        }
        XCTAssertEqual(axis(1, 2, 3), SIMD3(1, 0, 0))
        XCTAssertEqual(axis(3, 1, 2), SIMD3(0, 1, 0))
        XCTAssertEqual(axis(3, 2, 1), SIMD3(0, 0, 1))
        XCTAssertEqual(axis(1, 1, 1), SIMD3(1, 0, 0), "A tie takes the first axis")
    }

    // MARK: - Walk-around box

    func testTheBoxTurnIsKeptWithinAHalfTurn() {
        XCTAssertEqual(BoxFit.normalizedYaw(-0.1), .pi - 0.1, accuracy: 1e-5)
        XCTAssertEqual(BoxFit.normalizedYaw(0.5), 0.5, accuracy: 1e-6)
        XCTAssertEqual(BoxFit.normalizedYaw(.pi + 0.2), 0.2, accuracy: 1e-5)
    }

    func testASideSettlesOnTheMedianOfItsPointsOrStaysPut() {
        XCTAssertEqual(BoxFit.settledFace([1.0, 1.01, 5.0], at: 1.0), 1.01, accuracy: 1e-6)
        XCTAssertEqual(BoxFit.settledFace([1.0, 5.0], at: 3.0), 3.0, "No point near the edge: it stays where it is")
    }

    func testStrayPointsAboveTheFurnitureDontRaiseTheTop() {
        let heights = Array(repeating: Float(0.5), count: 100) + [2.0, 2.1]
        XCTAssertEqual(BoxFit.topHeight(of: heights), 0.5, accuracy: 1e-6)
    }

    // MARK: - Scan model

    func testTheSmallestOutlinedFaceUnderATapWins() {
        let outer = DetectedQuad(corners: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.1),
                                           CGPoint(x: 0.9, y: 0.9), CGPoint(x: 0.1, y: 0.9)])
        let inner = DetectedQuad(corners: [CGPoint(x: 0.4, y: 0.4), CGPoint(x: 0.6, y: 0.4),
                                           CGPoint(x: 0.6, y: 0.6), CGPoint(x: 0.4, y: 0.6)])
        XCTAssertEqual(ScanModel.smallestFace(under: CGPoint(x: 0.5, y: 0.5), in: [outer, inner])?.corners, inner.corners)
        XCTAssertEqual(ScanModel.smallestFace(under: CGPoint(x: 0.2, y: 0.2), in: [outer, inner])?.corners, outer.corners)
        XCTAssertNil(ScanModel.smallestFace(under: CGPoint(x: 0.95, y: 0.95), in: [outer, inner]))
    }

    func testFinishingACornerDragWithNothingCapturedChangesNothing() {
        let model = ScanModel(source: DemoFrameSource())
        model.finishMovingCorner()
        XCTAssertEqual(model.status, .aiming)
    }

    // MARK: - Samples, bridge and proof

    func testASampleWithNoPartsStillHasASummary() {
        XCTAssertEqual(SamplePiece(id: "a", name: "A", inventory: Inventory(parts: [], scanID: "s")).summary, "0 parts")
    }

    func testAToolWithNoObjectParametersHasNoneToSend() {
        let spec = ToolSpec(name: "t", description: "d", parameters: .string("just text"))
        let result = AgentBridge.parameters(of: spec)
        XCTAssertTrue(result.properties.isEmpty)
        XCTAssertEqual(result.optional, [])
    }

    func testOptionalToolParametersAreNamed() {
        let spec = ToolSpec(name: "t", description: "d", parameters: .object([
            ParamProperty(name: "a", schema: .string("x")), ParamProperty(name: "b", schema: .number("y"), required: false),
        ], "Args."))
        XCTAssertEqual(AgentBridge.parameters(of: spec).optional, ["b"])
    }
}
