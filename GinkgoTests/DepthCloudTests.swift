import simd
import XCTest
@testable import Ginkgo

final class DepthCloudTests: XCTestCase {
    /// A camera pose: at `position`, looking along `forward` (world), with y up.
    private func pose(at position: SIMD3<Float>, looking forward: SIMD3<Float>) -> simd_float4x4 {
        let back = -simd_normalize(forward)
        let right = simd_normalize(simd_cross(SIMD3(0, 1, 0), back))
        let up = simd_cross(back, right)
        return simd_float4x4(SIMD4(right, 0), SIMD4(up, 0), SIMD4(back, 0), SIMD4(position, 1))
    }

    func testAFlatWallInFrontLandsWhereItIs() {
        // Camera at the origin looking down -z at a wall 1 m away.
        var cloud = DepthCloud()
        cloud.add(makeSnapshot(depth: { _, _ in 1.0 }), cameraToWorld: matrix_identity_float4x4)
        XCTAssertGreaterThan(cloud.count, 1000)
        for p in cloud.points { XCTAssertEqual(p.z, -1.0, accuracy: 0.001) }
    }

    func testTheCameraPosePlacesPointsInTheRoom() {
        // The same 1 m reading from a camera 2 m to the right, looking along -x: the wall is at x = 1.
        var cloud = DepthCloud()
        cloud.add(makeSnapshot(depth: { _, _ in 1.0 }), cameraToWorld: pose(at: SIMD3(2, 0, 0), looking: SIMD3(-1, 0, 0)))
        for p in cloud.points { XCTAssertEqual(p.x, 1.0, accuracy: 0.001) }
    }

    func testOnlyConfidentNearReadingsAreKept() {
        var cloud = DepthCloud()
        cloud.add(makeSnapshot(depth: { x, _ in x < 96 ? 1.0 : 1.0 }, confidence: { x, _ in x < 96 ? 2 : 1 }),
                  cameraToWorld: matrix_identity_float4x4)
        let half = cloud.count
        var far = DepthCloud()
        far.add(makeSnapshot(depth: { _, _ in 4.0 }), cameraToWorld: matrix_identity_float4x4)
        XCTAssertEqual(far.count, 0, "Beyond \(DepthCloud.maxRange) m is too noisy")
        var broken = DepthCloud()
        broken.add(makeSnapshot(depth: { x, _ in x % 2 == 0 ? .nan : 0 }), cameraToWorld: matrix_identity_float4x4)
        XCTAssertEqual(broken.count, 0)
        var all = DepthCloud()
        all.add(makeSnapshot(depth: { _, _ in 1.0 }), cameraToWorld: matrix_identity_float4x4)
        XCTAssertEqual(Double(half), Double(all.count) / 2, accuracy: Double(all.count) * 0.05, "Low confidence is dropped")
    }

    func testSeeingTheSameSurfaceTwiceDoesNotDoubleIt() {
        var cloud = DepthCloud()
        let frame = makeSnapshot(depth: { _, _ in 1.0 })
        cloud.add(frame, cameraToWorld: matrix_identity_float4x4)
        let once = cloud.count
        cloud.add(frame, cameraToWorld: matrix_identity_float4x4)
        XCTAssertEqual(cloud.count, once)
    }
}

final class BoxRefineTests: XCTestCase {
    /// Dense, precise points on a box's sides and top, plus the floor around it, like accumulated LiDAR depth.
    private func preciseScene(length: Float, width: Float, height: Float, floorY: Float = 0) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        let step: Float = 0.005
        for y in stride(from: floorY + 0.01, through: floorY + height, by: step) {
            for u in stride(from: -length / 2, through: length / 2, by: step) {
                points += [SIMD3(u, y, -width / 2), SIMD3(u, y, width / 2)]
            }
            for v in stride(from: -width / 2, through: width / 2, by: step) {
                points += [SIMD3(-length / 2, y, v), SIMD3(length / 2, y, v)]
            }
        }
        for u in stride(from: -length / 2, through: length / 2, by: step) {
            for v in stride(from: -width / 2, through: width / 2, by: step) { points.append(SIMD3(u, floorY + height, v)) }
        }
        for x in stride(from: Float(-0.6), through: 0.6, by: 0.01) {
            for z in stride(from: Float(-0.6), through: 0.6, by: 0.01) where abs(x) > length / 2 + 0.02 || abs(z) > width / 2 + 0.02 {
                points.append(SIMD3(x, floorY, z))
            }
        }
        return points
    }

    func testARoundedMeshBoxIsCorrectedByPreciseDepth() throws {
        // The mesh box came out 3 cm too big on every side and 2 cm too low a floor, like the real scans.
        let coarse = FittedBox(length: 0.44, width: 0.345, height: 0.34, baseCenter: SIMD3(0, -0.02, 0), yaw: 0,
                               uncertainty: 0.038, pointCount: 3000)
        let refined = try XCTUnwrap(BoxFit.refine(coarse, cloud: preciseScene(length: 0.41, width: 0.315, height: 0.31)))
        XCTAssertEqual(refined.length, 0.41, accuracy: 0.004)
        XCTAssertEqual(refined.width, 0.315, accuracy: 0.004)
        XCTAssertEqual(refined.height, 0.31, accuracy: 0.004)
        XCTAssertEqual(refined.baseCenter.y, 0, accuracy: 0.002, "The floor comes from depth points around the piece")
        XCTAssertLessThan(refined.uncertainty, 0.005)
    }

    func testANeighborOutsideTheMarginIsIgnored() throws {
        let coarse = FittedBox(length: 0.43, width: 0.33, height: 0.33, baseCenter: .zero, yaw: 0, uncertainty: 0.03, pointCount: 3000)
        let neighbor = (0..<2000).map { i in SIMD3<Float>(0.5, 0.05 + Float(i % 40) * 0.01, -0.1 + Float(i / 40) * 0.004) }
        let refined = try XCTUnwrap(BoxFit.refine(coarse, cloud: preciseScene(length: 0.41, width: 0.315, height: 0.31) + neighbor))
        XCTAssertEqual(refined.length, 0.41, accuracy: 0.004)
    }

    func testNotEnoughDepthGivesNoRefinement() {
        let coarse = FittedBox(length: 0.4, width: 0.3, height: 0.3, baseCenter: .zero, yaw: 0, uncertainty: 0.03, pointCount: 3000)
        XCTAssertNil(BoxFit.refine(coarse, cloud: []))
    }
}
