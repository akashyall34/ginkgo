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

/// Furniture other than the sample nightstand: every panel type, and pieces with no top or no sides.
final class TransformFurnitureTests: XCTestCase {
    private func part(_ id: String, _ type: TypeEnum, w: Double, h: Double, t: Double = 19) -> Part {
        Part(damaged: false, heightMm: h, id: id, keepOuts: [], material: .solidWood, thicknessMm: t, type: type, widthMm: w)
    }

    private func poses(_ parts: [Part]) -> [String: PanelPose] {
        TransformLayout.furniture(Inventory(parts: parts, scanID: "s"))
    }

    /// A 600 wide, 400 deep, 800 tall cabinet.
    private let cabinet: [Part] = [
        Part(damaged: false, heightMm: 400, id: "top", keepOuts: [], material: .solidWood, thicknessMm: 20, type: .top,
             widthMm: 600),
        Part(damaged: false, heightMm: 800, id: "side", keepOuts: [], material: .solidWood, thicknessMm: 20, type: .side,
             widthMm: 400),
    ]

    func testTheBackStandsAtTheBackOnTheFloor() throws {
        let back = try XCTUnwrap(poses(cabinet + [part("back", .back, w: 560, h: 780, t: 6)])["back"])
        XCTAssertEqual(back.position.x, 0, accuracy: 1e-6)
        XCTAssertEqual(back.position.y, 0.39, accuracy: 1e-6, "Half its height: it stands on the floor")
        XCTAssertEqual(back.position.z, -(0.2 - 0.003), accuracy: 1e-6, "Flush with the back edge")
        XCTAssertEqual(back.rotation, TransformLayout.rotation(degrees: TransformLayout.upright))
    }

    func testAShelfLiesFlatHalfwayUp() throws {
        let shelf = try XCTUnwrap(poses(cabinet + [part("shelf", .shelf, w: 560, h: 380)])["shelf"])
        XCTAssertEqual(shelf.position, SIMD3(0, 0.4, 0))
        XCTAssertEqual(shelf.rotation, TransformLayout.rotation(degrees: TransformLayout.flat))
    }

    func testDrawerBoxesLegsAndRailsStandUprightOnTheFloorAtTheCenter() throws {
        let extras = [part("box", .drawerBox, w: 300, h: 120), part("leg", .leg, w: 40, h: 700),
                      part("rail", .rail, w: 500, h: 60)]
        let all = poses(cabinet + extras)
        for extra in extras {
            let pose = try XCTUnwrap(all[extra.id])
            XCTAssertEqual(pose.position, SIMD3(0, Float(extra.heightMm / 2000), 0), extra.id)
            XCTAssertEqual(pose.rotation, TransformLayout.rotation(degrees: TransformLayout.upright), extra.id)
            XCTAssertEqual(pose.size, SIMD3(Float(extra.widthMm / 1000), Float(extra.heightMm / 1000), 0.019), extra.id)
        }
    }

    func testWithNoTopTheSidesSetTheWidthAndDepth() throws {
        // No top: width falls back to the first side's height, depth to its width.
        let all = poses([part("left", .side, w: 300, h: 500), part("right", .side, w: 300, h: 500),
                         part("front", .drawerFront, w: 400, h: 100)])
        XCTAssertEqual(try XCTUnwrap(all["right"]).position.x, 0.25 - 0.0095, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(all["front"]).position.z, 0.15 - 0.0095, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(all["front"]).position.y, 0.5 - 0.05, accuracy: 1e-6, "Its top at the sides' top")
    }

    func testWithNoTopAndNoSidesTheDefaultBoxIsUsed() throws {
        // 400 × 400 footprint, 500 tall.
        let all = poses([part("front", .drawerFront, w: 400, h: 100), part("shelf", .shelf, w: 300, h: 300)])
        XCTAssertEqual(try XCTUnwrap(all["front"]).position, SIMD3(0, 0.45, 0.2 - 0.0095))
        XCTAssertEqual(try XCTUnwrap(all["shelf"]).position.y, 0.25, accuracy: 1e-6)
    }

    func testEmptyFurnitureHasNoPanels() {
        XCTAssertEqual(poses([]), [:])
    }

    func testACutPieceKeepsItsPanelsThickness() throws {
        let inventory = Inventory(parts: cabinet, scanID: "s")
        let plan = try XCTUnwrap(RuleBasedPlanner.bench(inventory: Inventory(parts: cabinet + [
            Part(damaged: false, heightMm: 800, id: "side2", keepOuts: [], material: .solidWood, thicknessMm: 20,
                 type: .side, widthMm: 400),
        ], scanID: "s"))?.plan)
        let scene = TransformLayout.scene(plan: plan, inventory: Inventory(parts: inventory.parts + [
            Part(damaged: false, heightMm: 800, id: "side2", keepOuts: [], material: .solidWood, thicknessMm: 20,
                 type: .side, widthMm: 400),
        ], scanID: "s"))
        XCTAssertFalse(scene.pieces.isEmpty)
        for piece in scene.pieces {
            XCTAssertEqual(piece.start.size.z, 0.02, accuracy: 1e-6, piece.name)
            XCTAssertEqual(piece.end.size.z, 0.02, accuracy: 1e-6, piece.name)
        }
    }
}
