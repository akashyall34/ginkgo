@testable import GinkgoCore
import XCTest

final class LayoutTests: XCTestCase {
    private func draftPart(_ name: String, _ source: String, _ size: [Double], _ role: Role) -> DraftPart {
        DraftPart(heightMm: size[1], name: name, role: role, sourcePartID: source, spanMm: nil, widthMm: size[0])
    }

    private func draft(_ parts: [DraftPart], _ template: Template) -> PlanDraft {
        PlanDraft(hardware: [], newParts: parts, steps: ["Build it."], template: template)
    }

    private func part(_ id: String, _ size: [Double], thickness: Double) -> Part {
        Part(damaged: false, heightMm: size[1], id: id, keepOuts: [], material: .plywood, thicknessMm: thickness,
             type: .side, widthMm: size[0])
    }

    private func vector(_ x: Double, _ y: Double, _ z: Double) -> Vector3 {
        Vector3(x: x, y: y, z: z)
    }

    private func named(_ plan: Plan, _ name: String) throws -> NewPart {
        try XCTUnwrap(plan.newParts.first { $0.name == name })
    }

    // MARK: - Bench

    func testSampleBench() throws {
        let plan = Layout.plan(from: try Fixtures.benchDraft(), inventory: try Fixtures.inventory(), id: "plan-1")
        XCTAssertEqual(try named(plan, "leg_left").positionMm, vector(-190.5, 190, 0))
        XCTAssertEqual(try named(plan, "leg_right").positionMm, vector(190.5, 190, 0))
        XCTAssertEqual(try named(plan, "leg_left").rotationDeg, vector(0, 90, 0))
        XCTAssertEqual(try named(plan, "seat").positionMm, vector(0, 389.5, 0))
        XCTAssertEqual(try named(plan, "seat").rotationDeg, vector(90, 0, 0))
        XCTAssertEqual(plan.overallMm, vector(400, 399, 300))
    }

    func testLayoutFillsInThePlanAroundTheParts() throws {
        let draft = try Fixtures.benchDraft()
        let plan = Layout.plan(from: draft, inventory: try Fixtures.inventory(), id: "plan-1")
        XCTAssertEqual(plan.id, "plan-1")
        XCTAssertEqual(plan.scanID, "scan-nightstand-1")
        XCTAssertEqual(plan.source, .ginkgo)
        XCTAssertEqual(plan.template, .bench)
        XCTAssertEqual(plan.steps, draft.steps)
        XCTAssertEqual(plan.hardware, draft.hardware)
        XCTAssertEqual(plan.newParts.map(\.name), ["seat", "leg_left", "leg_right"], "draft order is kept")
        XCTAssertEqual(plan.newParts.first?.spanMm, 360)
        XCTAssertEqual(plan.newParts.first?.widthMm, 400)
    }

    func testLaidOutSamplePlanPassesTheValidatorWithItsOverallSize() throws {
        let inventory = try Fixtures.inventory()
        let plan = Layout.plan(from: try Fixtures.benchDraft(), inventory: inventory, id: "plan-1")
        let fits = SizeLimits(maxDepthMm: 300, maxHeightMm: 399, maxWidthMm: 400)
        XCTAssertTrue(Validator.validate(plan: plan, inventory: inventory, limits: fits).passes)
        let tooNarrow = SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: 399)
        XCTAssertEqual(Validator.validate(plan: plan, inventory: inventory, limits: tooNarrow).violations.map(\.code), [.tooLarge])
    }

    func testTwoSeatsSitSideBySideAlongZ() throws {
        let parts = [
            draftPart("front", "top", [400, 200], .seat), draftPart("back", "top", [400, 100], .seat),
            draftPart("left", "side_left", [300, 380], .support), draftPart("right", "side_right", [300, 380], .support),
        ]
        let plan = Layout.plan(from: draft(parts, .bench), inventory: try Fixtures.inventory(), id: "p")
        XCTAssertEqual(try named(plan, "front").positionMm, vector(0, 389.5, -50))
        XCTAssertEqual(try named(plan, "back").positionMm, vector(0, 389.5, 100))
        XCTAssertEqual(plan.overallMm, vector(400, 399, 300))
    }

    func testExtraPartsInABenchStandBesideIt() throws {
        let parts = try Fixtures.benchDraft().newParts + [draftPart("shelf_sign", "side_left", [60, 100], .other)]
        let plan = Layout.plan(from: draft(parts, .bench), inventory: try Fixtures.inventory(), id: "p")
        XCTAssertEqual(try named(plan, "shelf_sign").positionMm, vector(250, 50, 0), "20 mm right of the bench's edge at 200")
        XCTAssertEqual(try named(plan, "shelf_sign").rotationDeg, vector(0, 0, 0))
        XCTAssertEqual(plan.overallMm, vector(480, 399, 300))
    }

    // MARK: - Bookshelf

    func testBookshelfWithThreeEvenlySpacedShelves() throws {
        let inventory = Inventory(parts: [part("side_a", [300, 900], thickness: 18), part("side_b", [300, 900], thickness: 18),
                                          part("board", [600, 900], thickness: 18), part("panel", [564, 900], thickness: 6)],
                                  scanID: "scan-2")
        let parts = [
            draftPart("left", "side_a", [300, 900], .side), draftPart("right", "side_b", [300, 900], .side),
            draftPart("bottom", "board", [564, 280], .shelf), draftPart("middle", "board", [564, 280], .shelf),
            draftPart("top", "board", [564, 280], .shelf), draftPart("back", "panel", [564, 900], .back),
        ]
        let plan = Layout.plan(from: draft(parts, .bookshelf), inventory: inventory, id: "p")
        XCTAssertEqual(try named(plan, "left").positionMm, vector(-291, 450, 0))
        XCTAssertEqual(try named(plan, "right").positionMm, vector(291, 450, 0))
        XCTAssertEqual(try ["bottom", "middle", "top"].map { try named(plan, $0).positionMm.y }, [9, 450, 891])
        XCTAssertEqual(try named(plan, "middle").rotationDeg, vector(90, 0, 0))
        XCTAssertEqual(try named(plan, "back").positionMm, vector(0, 450, -147))
        XCTAssertEqual(plan.overallMm, vector(600, 900, 300))
        XCTAssertEqual(plan.scanID, "scan-2")
    }

    func testBookshelfWithOneShelfPutsItAtTheBottom() throws {
        let inventory = Inventory(parts: [part("board", [600, 900], thickness: 18)], scanID: "s")
        let parts = [draftPart("left", "board", [300, 900], .side), draftPart("only", "board", [564, 280], .shelf)]
        let plan = Layout.plan(from: draft(parts, .bookshelf), inventory: inventory, id: "p")
        XCTAssertEqual(try named(plan, "only").positionMm.y, 9)
    }

    // MARK: - No cut

    func testOnePartNoCutStandsOnTheFloorAtTheCentre() throws {
        let parts = [draftPart("cubby", "side_left", [380, 560], .other)]
        let plan = Layout.plan(from: draft(parts, .noCut), inventory: try Fixtures.inventory(), id: "p")
        XCTAssertEqual(try named(plan, "cubby").positionMm, vector(0, 280, 0))
        XCTAssertEqual(plan.overallMm, vector(380, 560, 19))
    }

    func testNoCutPartsStandInARowWithGaps() throws {
        let parts = [draftPart("a", "side_left", [380, 560], .other), draftPart("b", "top", [460, 400], .other)]
        let plan = Layout.plan(from: draft(parts, .noCut), inventory: try Fixtures.inventory(), id: "p")
        XCTAssertEqual(try named(plan, "a").positionMm, vector(-240, 280, 0))
        XCTAssertEqual(try named(plan, "b").positionMm, vector(200, 200, 0), "starts at -430 + 380 + 20 = -30")
        XCTAssertEqual(plan.overallMm, vector(860, 560, 19))
    }

    // MARK: - Odd input

    func testUnknownSourceStillLaysOutWithPlaceholderThickness() throws {
        let parts = [draftPart("seat", "nope", [400, 300], .seat), draftPart("leg", "side_left", [300, 380], .support)]
        let plan = Layout.plan(from: draft(parts, .bench), inventory: try Fixtures.inventory(), id: "p")
        XCTAssertEqual(try named(plan, "seat").positionMm.y, 389, "380 + 18 / 2")
        XCTAssertFalse(Validator.validate(plan: plan, inventory: try Fixtures.inventory(), limits: nil).passes,
                       "the validator, not Layout, rejects the unknown part")
    }

    func testEmptyDraftGivesAZeroSize() throws {
        let plan = Layout.plan(from: draft([], .bench), inventory: try Fixtures.inventory(), id: "p")
        XCTAssertEqual(plan.newParts, [])
        XCTAssertEqual(plan.overallMm, vector(0, 0, 0))
    }

    func testRotationExtents() {
        let panel = vector(400, 300, 19)
        XCTAssertEqual(Rotation.extent(of: panel, rotatedBy: vector(0, 0, 0)), vector(400, 300, 19))
        XCTAssertEqual(Rotation.extent(of: panel, rotatedBy: vector(90, 0, 0)), vector(400, 19, 300))
        XCTAssertEqual(Rotation.extent(of: panel, rotatedBy: vector(0, 90, 0)), vector(19, 300, 400))
        XCTAssertEqual(Rotation.extent(of: panel, rotatedBy: vector(0, 0, 90)), vector(300, 400, 19))
        XCTAssertEqual(Rotation.clean(-0.0001), 0)
    }
}
