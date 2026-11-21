import XCTest
import simd
@testable import Ginkgo

final class PlaneFitTests: XCTestCase {
    func testEigenvectorOfDiagonalMatrix() {
        let m = simd_float3x3(diagonal: SIMD3(3, 1, 2))
        let v = SymmetricEigen.smallestEigenvector(m)
        XCTAssertEqual(abs(v.y), 1, accuracy: 1e-5)
    }

    func testEigenvectorOfRotatedMatrix() {
        // Smallest eigenvalue along a known tilted axis.
        let axis = simd_normalize(SIMD3<Float>(1, 2, 2))
        let r = simd_float3x3(simd_quatf(from: SIMD3(0, 0, 1), to: axis))
        let m = r * simd_float3x3(diagonal: SIMD3(4, 5, 0.1)) * r.transpose
        let v = SymmetricEigen.smallestEigenvector(m)
        XCTAssertEqual(abs(simd_dot(v, axis)), 1, accuracy: 1e-4)
    }

    func testPlaneThroughThreePoints() throws {
        let p = try XCTUnwrap(Plane.through(SIMD3(0, 0, -1), SIMD3(1, 0, -1), SIMD3(0, 1, -1)))
        XCTAssertEqual(abs(p.normal.z), 1, accuracy: 1e-6)
        XCTAssertEqual(p.distance(to: SIMD3(5, 5, -1)), 0, accuracy: 1e-5)
        XCTAssertEqual(p.distance(to: SIMD3(0, 0, -3)), 2, accuracy: 1e-5)
    }

    func testCollinearPointsGiveNoPlane() {
        XCTAssertNil(Plane.through(SIMD3(0, 0, 0), SIMD3(1, 1, 1), SIMD3(2, 2, 2)))
    }

    func testRayHitsPlaneInFrontOnly() throws {
        let wall = Plane(normal: SIMD3(0, 0, 1), offset: 2) // z = -2
        XCTAssertEqual(try XCTUnwrap(wall.hit(direction: SIMD3(0, 0, -1))), 2, accuracy: 1e-6)
        XCTAssertNil(wall.hit(direction: SIMD3(0, 0, 1)), "Plane is behind this ray")
        XCTAssertNil(wall.hit(direction: SIMD3(1, 0, 0)), "Ray runs parallel to the plane")
    }

    func testLeastSquaresRecoversExactPlane() throws {
        var pts: [SIMD3<Float>] = []
        for x in stride(from: -0.5, through: 0.5, by: 0.1) {
            for y in stride(from: -0.5, through: 0.5, by: 0.1) {
                pts.append(SIMD3(Float(x), Float(y), -1 + 0.5 * Float(x)))
            }
        }
        let p = try XCTUnwrap(Plane.leastSquares(pts))
        for q in pts { XCTAssertEqual(p.distance(to: q), 0, accuracy: 1e-4) }
    }

    func testRansacIgnoresAnotherSurface() throws {
        var pts: [SIMD3<Float>] = []
        for i in 0..<300 { pts.append(SIMD3(Float(i % 20) * 0.02, Float(i / 20) * 0.02, -1)) } // main surface
        for i in 0..<100 { pts.append(SIMD3(Float(i % 10) * 0.05, Float(i / 10) * 0.05, -3)) } // wall behind
        let fit = try XCTUnwrap(RansacPlaneFitter().fit(pts))
        XCTAssertEqual(fit.inlierCount, 300)
        XCTAssertEqual(fit.plane.distance(to: SIMD3(0.3, 0.1, -1)), 0, accuracy: 1e-4)
        XCTAssertEqual(fit.rms, 0, accuracy: 1e-4)
    }

    func testRansacIsRepeatable() throws {
        var gen = SeededGenerator(seed: 7)
        let pts = (0..<500).map { _ in
            SIMD3<Float>(gen.nextUniform(), gen.nextUniform(), -1 + 0.003 * gen.nextNormal())
        }
        let a = try XCTUnwrap(RansacPlaneFitter().fit(pts))
        let b = try XCTUnwrap(RansacPlaneFitter().fit(pts))
        XCTAssertEqual(a.plane, b.plane)
        XCTAssertEqual(a.inlierCount, b.inlierCount)
    }
}
