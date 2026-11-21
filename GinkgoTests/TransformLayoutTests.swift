import GinkgoCore
import simd
import XCTest
@testable import Ginkgo

final class TransformLayoutTests: XCTestCase {
    private func inventory() throws -> Inventory {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        return try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
    }

    private func bench() throws -> Plan {
        try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory())?.plan)
    }

    /// The eight corners of a posed panel, in world space.
    private func corners(_ pose: PanelPose) -> [SIMD3<Float>] {
        [-1, 1].flatMap { x in [-1, 1].flatMap { y in [-1, 1].map { z in
            pose.position + pose.rotation.act(pose.size / 2 * SIMD3<Float>(x, y, z))
        } } }
    }

    private func assertClose(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ message: String = "", line: UInt = #line) {
        XCTAssertLessThan(simd_distance(a, b), 1e-4, "\(a) vs \(b) \(message)", line: line)
    }

    // MARK: the rotation convention

    func testFlatLaysThePanelsHeightAlongDepth() {
        assertClose(TransformLayout.rotation(degrees: TransformLayout.flat).act(SIMD3(0, 1, 0)), SIMD3(0, 0, 1))
    }

    func testSidewaysTurnsTheWidthIntoDepth() {
        assertClose(TransformLayout.rotation(degrees: TransformLayout.sideways).act(SIMD3(1, 0, 0)), SIMD3(0, 0, -1))
    }

    func testRotationsApplyXThenYThenZ() {
        // y → z (about x), then z → x (about y).
        assertClose(TransformLayout.rotation(degrees: Vector3(x: 90, y: 90, z: 0)).act(SIMD3(0, 1, 0)), SIMD3(1, 0, 0))
    }

    // MARK: the old furniture

    func testTheNightstandIsAssembledAsABox() throws {
        let poses = TransformLayout.furniture(try inventory())
        let top = try XCTUnwrap(poses["top"])
        XCTAssertEqual(top.position.y, 0.56 + 0.0095, accuracy: 1e-5, "The top rests on the 560 mm sides")
        XCTAssertEqual(try XCTUnwrap(poses["side_left"]).position.x, -(0.23 - 0.0095), accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(poses["side_right"]).position.x, 0.23 - 0.0095, accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(poses["drawer_front"]).position.z, 0.2 - 0.0095, accuracy: 1e-5, "At the front")
        for (id, pose) in poses {
            XCTAssertGreaterThanOrEqual(corners(pose).map(\.y).min() ?? -1, -1e-4, "\(id) sinks into the floor")
        }
    }

    func testTheTopLiesFlatAndTheSidesStandUp() throws {
        let poses = TransformLayout.furniture(try inventory())
        let top = corners(try XCTUnwrap(poses["top"])).map(\.y)
        XCTAssertEqual((top.max() ?? 0) - (top.min() ?? 0), 0.019, accuracy: 1e-5, "Only its thickness is vertical")
        let side = corners(try XCTUnwrap(poses["side_left"])).map(\.y)
        XCTAssertEqual((side.max() ?? 0) - (side.min() ?? 0), 0.56, accuracy: 1e-5)
    }

    // MARK: old → new

    func testEveryPieceComesOutOfItsOwnPanel() throws {
        let inventory = try inventory()
        let plan = try bench()
        let scene = TransformLayout.scene(plan: plan, inventory: inventory)
        let old = TransformLayout.furniture(inventory)
        XCTAssertEqual(scene.pieces.map(\.name), plan.newParts.map(\.name))
        for piece in scene.pieces {
            assertClose(piece.start.position, try XCTUnwrap(old[piece.sourcePartID]).position, piece.name)
        }
    }

    func testTheBenchStandsOnTheFloor() throws {
        let scene = TransformLayout.scene(plan: try bench(), inventory: try inventory())
        let lowest = scene.pieces.flatMap { corners($0.end) }.map(\.y).min() ?? -1
        XCTAssertEqual(lowest, 0, accuracy: 0.002, "Vivek's layout and this conversion agree: nothing floats or sinks")
    }

    func testEndPositionsAreThePlansInMeters() throws {
        let plan = try bench()
        let scene = TransformLayout.scene(plan: plan, inventory: try inventory())
        for (piece, part) in zip(scene.pieces, plan.newParts) {
            assertClose(piece.end.position, SIMD3(Float(part.positionMm.x), Float(part.positionMm.y), Float(part.positionMm.z)) / 1000)
            XCTAssertEqual(piece.end.size.x, Float(part.widthMm) / 1000, accuracy: 1e-6)
        }
    }

    func testTheDamagedDrawerFrontIsLeftOver() throws {
        let scene = TransformLayout.scene(plan: try bench(), inventory: try inventory())
        XCTAssertEqual(Set(scene.unused.keys), ["drawer_front"])
    }

    func testAPieceFromAnUnknownPanelIsSkipped() throws {
        let plan = try bench()
        let bad = try JSONDecoder().decode(Plan.self, from: JSONEncoder().encode(plan).replacingSourcePart(with: "ghost"))
        XCTAssertEqual(TransformLayout.scene(plan: bad, inventory: try inventory()).pieces, [])
    }
}

private extension Data {
    /// The same plan JSON with every source part id replaced.
    func replacingSourcePart(with id: String) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: self) as? [String: Any])
        let parts = try XCTUnwrap(object["new_parts"] as? [[String: Any]])
        object["new_parts"] = parts.map { var p = $0; p["source_part_id"] = id; return p }
        return try JSONSerialization.data(withJSONObject: object)
    }
}

final class TransformExampleTests: XCTestCase {
    func testTheExampleIsTheBenchFromTheSampleNightstand() throws {
        let scene = try XCTUnwrap(TransformLayout.example())
        XCTAssertFalse(scene.pieces.isEmpty)
        XCTAssertEqual(Set(scene.unused.keys), ["drawer_front"])
    }

    func testNoSampleDataMeansNoExample() {
        XCTAssertNil(TransformLayout.example(bundle: Bundle(for: TransformExampleTests.self)))
    }
}
