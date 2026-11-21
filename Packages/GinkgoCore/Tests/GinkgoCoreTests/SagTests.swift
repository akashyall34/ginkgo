@testable import GinkgoCore
import XCTest

final class SagTests: XCTestCase {
    private let accuracy = 0.001

    private func source(thickness: Double, _ material: Material) -> Part {
        Part(damaged: false, heightMm: 600, id: "panel", keepOuts: [], material: material,
             thicknessMm: thickness, type: .side, widthMm: 1000)
    }

    private func check(_ role: Role, span: Double, depth: Double, source: Part) throws -> SagResult {
        try XCTUnwrap(try Sag.check(name: "part", role: role, spanMm: span, depthMm: depth, source: source))
    }

    // MARK: - Known answers (worked out by hand in the guide)

    func testSeatSpan360OnSolidWoodPasses() throws {
        let result = try check(.seat, span: 360, depth: 300, source: source(thickness: 19, .solidWood))
        XCTAssertEqual(result.deflectionMm, 0.386, accuracy: accuracy)
        XCTAssertEqual(result.limitMm, 0.600, accuracy: accuracy)
        XCTAssertTrue(result.passes)
        XCTAssertEqual(result.spanMm, 360)
        XCTAssertEqual(result.newPart, "part")
    }

    func testSeatSpan414OnSolidWoodPasses() throws {
        let result = try check(.seat, span: 414, depth: 392, source: source(thickness: 19, .solidWood))
        XCTAssertEqual(result.deflectionMm, 0.449, accuracy: accuracy)
        XCTAssertEqual(result.limitMm, 0.690, accuracy: accuracy)
        XCTAssertTrue(result.passes)
    }

    func testLongPlywoodShelfSags() throws {
        let result = try check(.shelf, span: 900, depth: 280, source: source(thickness: 18, .plywood))
        XCTAssertEqual(result.deflectionMm, 2.933, accuracy: accuracy)
        XCTAssertEqual(result.limitMm, 1.500, accuracy: accuracy)
        XCTAssertFalse(result.passes)
    }

    func testParticleboardShelfSags() throws {
        let result = try check(.shelf, span: 800, depth: 300, source: source(thickness: 16, .particleboardMDF))
        XCTAssertEqual(result.deflectionMm, 7.664, accuracy: accuracy)
        XCTAssertEqual(result.limitMm, 1.333, accuracy: accuracy)
        XCTAssertFalse(result.passes)
    }

    func testFallbackSeatFromTheGuide() throws {
        let result = try check(.seat, span: 414, depth: 362, source: source(thickness: 19, .solidWood))
        XCTAssertEqual(result.deflectionMm, 0.487, accuracy: accuracy)
        XCTAssertTrue(result.passes)
    }

    // MARK: - Boundaries

    func testPassFailBoundaryNearTheLimit() throws {
        // Span 360 seat: deflection × depth ≈ 115.85, so the limit of 0.6 mm is crossed near depth 193 mm.
        let solid = source(thickness: 19, .solidWood)
        XCTAssertTrue(try check(.seat, span: 360, depth: 194, source: solid).passes)
        XCTAssertFalse(try check(.seat, span: 360, depth: 192, source: solid).passes)
    }

    func testLimitIsSpanOver600() {
        XCTAssertEqual(Sag.limit(spanMm: 600), 1)
        XCTAssertEqual(Sag.limit(spanMm: 900), 1.5)
    }

    func testZeroLoadGivesZeroDeflection() throws {
        XCTAssertEqual(try Sag.deflection(loadKg: 0, spanMm: 500, depthMm: 300, thicknessMm: 18, stiffness: 7000), 0)
    }

    func testStiffnessAndLoadTables() {
        XCTAssertEqual(Sag.stiffness(of: .solidWood), 9000)
        XCTAssertEqual(Sag.stiffness(of: .plywood), 7000)
        XCTAssertEqual(Sag.stiffness(of: .particleboardMDF), 2500)
        XCTAssertEqual(Sag.designLoadKg(for: .seat), 100)
        XCTAssertEqual(Sag.designLoadKg(for: .shelf), 30)
        for role in [Role.side, .support, .back, .other] {
            XCTAssertNil(Sag.designLoadKg(for: role))
        }
    }

    // MARK: - Invalid input becomes an error, never NaN

    func testZeroOrNegativeSizesThrow() {
        let solid = source(thickness: 19, .solidWood)
        XCTAssertThrowsError(try Sag.check(name: "s", role: .seat, spanMm: 0, depthMm: 300, source: solid)) { error in
            XCTAssertEqual(error as? SagError, .invalidSize("span must be more than 0 mm, got 0"))
        }
        XCTAssertThrowsError(try Sag.check(name: "s", role: .seat, spanMm: 360, depthMm: -5, source: solid)) { error in
            XCTAssertEqual((error as? SagError)?.message, "depth must be more than 0 mm, got -5")
        }
        XCTAssertThrowsError(try Sag.check(name: "s", role: .seat, spanMm: 360, depthMm: 300,
                                           source: source(thickness: 0, .solidWood)))
    }

    func testNonNumbersThrow() {
        XCTAssertThrowsError(try Sag.deflection(loadKg: 100, spanMm: .nan, depthMm: 300, thicknessMm: 19, stiffness: 9000))
        XCTAssertThrowsError(try Sag.deflection(loadKg: 100, spanMm: .infinity, depthMm: 300, thicknessMm: 19, stiffness: 9000))
        XCTAssertThrowsError(try Sag.deflection(loadKg: 100, spanMm: 360, depthMm: 300, thicknessMm: 19, stiffness: 0)) { error in
            XCTAssertEqual((error as? SagError)?.message, "stiffness must be more than 0 N/mm², got 0")
        }
        XCTAssertThrowsError(try Sag.deflection(loadKg: -1, spanMm: 360, depthMm: 300, thicknessMm: 19, stiffness: 9000)) { error in
            XCTAssertEqual((error as? SagError)?.message, "load must be 0 kg or more")
        }
        XCTAssertThrowsError(try Sag.deflection(loadKg: .nan, spanMm: 360, depthMm: 300, thicknessMm: 19, stiffness: 9000))
    }

    func testUnloadedRolesAreNotChecked() throws {
        let solid = source(thickness: 19, .solidWood)
        XCTAssertNil(try Sag.check(name: "leg", role: .support, spanMm: 360, depthMm: 300, source: solid))
        XCTAssertNil(try Sag.check(name: "side", role: .side, spanMm: 0, depthMm: 0, source: solid),
                     "a role with no load is skipped before its sizes are checked")
    }

    // MARK: - Parts of a plan

    func testSamplePlanSeatAndLeg() throws {
        let plan = try Fixtures.planBench()
        let parts = try Fixtures.inventory().parts
        let top = try XCTUnwrap(parts.first { $0.id == "top" })
        let seat = try XCTUnwrap(plan.newParts.first { $0.name == "seat" })
        let result = try XCTUnwrap(try Sag.check(seat, source: top))
        XCTAssertEqual(result.newPart, "seat")
        XCTAssertEqual(result.deflectionMm, 0.386, accuracy: accuracy)
        let leg = try XCTUnwrap(plan.newParts.first { $0.name == "leg_left" })
        XCTAssertNil(try Sag.check(leg, source: top))
    }

    func testMissingSpanUsesTheWidth() throws {
        let zero = Vector3(x: 0, y: 0, z: 0)
        let seat = NewPart(heightMm: 300, name: "seat", positionMm: zero, role: .seat, rotationDeg: zero,
                           sourcePartID: "top", spanMm: nil, widthMm: 360)
        let result = try XCTUnwrap(try Sag.check(seat, source: source(thickness: 19, .solidWood)))
        XCTAssertEqual(result.spanMm, 360)
        XCTAssertEqual(result.deflectionMm, 0.386, accuracy: accuracy)
    }
}
