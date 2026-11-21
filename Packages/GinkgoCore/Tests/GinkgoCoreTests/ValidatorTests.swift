@testable import GinkgoCore
import XCTest

final class ValidatorTests: XCTestCase {
    // MARK: - The sample plan

    func testSamplePlanPasses() throws {
        let result = try validate(Fixtures.planBench())
        XCTAssertTrue(result.passes)
        XCTAssertEqual(result.violations, [])
        XCTAssertEqual(result.planID, "plan-bench-1")
        XCTAssertEqual(result.reusePercent, 52.1)
        XCTAssertEqual(result.verify, [
            VerifyItem(dimension: .width, marginMm: 52, sourcePartID: "top"),
            VerifyItem(dimension: .height, marginMm: 62, sourcePartID: "top"),
            VerifyItem(dimension: .width, marginMm: 72, sourcePartID: "side_left"),
        ])
        XCTAssertEqual(result.placements.map(\.newPart), ["seat", "leg_left", "leg_right"])
        XCTAssertEqual(result.placements.first?.xMm, 4)
        XCTAssertEqual(result.placements.first?.yMm, 34)
        XCTAssertEqual(result.sag.map(\.newPart), ["seat"])
        XCTAssertEqual(try XCTUnwrap(result.sag.first).deflectionMm, 0.386, accuracy: 0.001)
    }

    func testEmptyStepsAndHardwareStillValidate() throws {
        let sample = try Fixtures.planBench()
        let plan = Plan(hardware: [], id: "p", newParts: sample.newParts, overallMm: nil, scanID: "s", source: .chatbot,
                        steps: [], template: .bench)
        XCTAssertTrue(try validate(plan).passes)
    }

    // MARK: - One test per violation code

    func testUnknownSourcePart() throws {
        let result = try validate(editing("seat") { $0.source = "shelf_9" })
        XCTAssertEqual(result.violations, [Violation(
            code: .unknownPart,
            message: "seat: there is no part \"shelf_9\". Use one of: top, side_left, side_right, drawer_front.",
            newPart: "seat")])
        XCTAssertEqual(result.placements.map(\.newPart), ["leg_left", "leg_right"], "an unknown source isn't packed")
        XCTAssertEqual(result.sag, [], "or sag-checked")
        XCTAssertFalse(result.passes)
    }

    func testDuplicateNameIsReportedOnce() throws {
        let result = try validate(editing("leg_right") { $0.name = "leg_left" })
        XCTAssertEqual(result.violations, [Violation(
            code: .partUsedTwice, message: "leg_left: two new parts have this name. Give each part its own name.",
            newPart: "leg_left")])
        let parts = try Fixtures.planBench().newParts
        let three = plan([parts[0], parts[1], rename(parts[2], "seat"), rename(parts[1], "seat")])
        XCTAssertEqual(try validate(three).violations.filter { $0.code == .partUsedTwice }.count, 1)
    }

    func testDamagedPartIsRejected() throws {
        let shim = EditablePart(name: "shim", source: "drawer_front", width: 100, height: 100, role: .other)
        let result = try validate(plan(Fixtures.planBench().newParts + [shim.newPart]))
        XCTAssertEqual(result.violations, [Violation(
            code: .damagedPartUsed, message: "shim: drawer_front is damaged and can't be used.", newPart: "shim")])
    }

    func testSeatFromTheDamagedDrawerFront() throws {
        let result = try validate(editing("seat") { $0.source = "drawer_front" })
        XCTAssertEqual(result.violations.map(\.code), [.damagedPartUsed, .doesNotFit])
    }

    func testCuttingParticleboardIsNotAllowed() throws {
        let inventory = try edited(material: .particleboardMDF, of: "top")
        let result = Validator.validate(plan: try Fixtures.planBench(), inventory: inventory, limits: nil)
        XCTAssertEqual(result.violations.map(\.code), [.cutNotAllowed, .sags], "a particleboard seat is also too bendy")
        XCTAssertEqual(result.violations.first?.message,
                       "seat: top is particleboard/MDF, which crumbles when cut. "
                        + "Reuse it whole (460 × 400 mm) instead of cutting 400 × 300 mm.")
    }

    func testParticleboardReusedWholeIsAllowed() throws {
        let inventory = try edited(material: .particleboardMDF, of: "top")
        let cubby = EditablePart(name: "cubby", source: "top", width: 460, height: 400, role: .other)
        let result = Validator.validate(plan: plan([cubby.newPart], template: .noCut), inventory: inventory, limits: nil)
        XCTAssertTrue(result.passes)
        XCTAssertEqual(result.placements.first?.xMm, 0, "a whole part isn't trimmed")
    }

    func testNoCutTemplateWithRealCuts() throws {
        let result = try validate(plan(Fixtures.planBench().newParts, template: .noCut))
        XCTAssertEqual(result.violations.map(\.code), [.cutNotAllowed, .cutNotAllowed, .cutNotAllowed])
        XCTAssertEqual(result.violations.first?.message,
                       "seat: the no_cut template reuses parts whole, but this cuts 400 × 300 mm from top (460 × 400 mm).")
    }

    func testSeatTooWideForAnyPanel() throws {
        let result = try validate(editing("seat") { $0.width = 453 })
        XCTAssertEqual(result.violations, [Violation(
            code: .doesNotFit,
            message: "seat: needs 461 × 308 mm including the 8 mm cutting margin, but top is 460 × 400 mm. "
                + "Fits with width 443 mm or less at height 300 mm.",
            newPart: "seat")])
    }

    func testFullSizeSeatHitsTheScrewHoles() throws {
        let result = try validate(editing("seat") {
            $0.width = 452
            $0.height = 392
        })
        XCTAssertEqual(result.violations.map(\.code), [.hitsKeepOut])
        XCTAssertEqual(result.violations.first?.message,
                       "seat: hits the screw holes or damage on top. "
                        + "Fits with height 362 mm or less at width 452 mm, or width 392 mm or less at height 392 mm.")
    }

    func testLongPlywoodShelfSags() throws {
        var inventory = try Fixtures.inventory()
        let board = Part(damaged: false, heightMm: 300, id: "board", keepOuts: [], material: .plywood, thicknessMm: 18,
                         type: .shelf, widthMm: 1000)
        inventory = Inventory(parts: inventory.parts + [board], scanID: inventory.scanID)
        let shelf = EditablePart(name: "shelf", source: "board", width: 900, height: 280, role: .shelf, span: 900)
        let result = Validator.validate(plan: plan(try Fixtures.planBench().newParts + [shelf.newPart]),
                                        inventory: inventory, limits: nil)
        XCTAssertEqual(result.violations, [Violation(
            code: .sags,
            message: "shelf: bends 2.9 mm under 30 kg; at most 1.5 mm is allowed. "
                + "Use a shorter span, a deeper part or a stiffer part.",
            newPart: "shelf")])
        XCTAssertEqual(result.sag.map(\.passes), [true, false])
    }

    func testTooLargeForTheUsersLimit() throws {
        let limits = SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: 300)
        let missing = try validate(Fixtures.planBench(), limits: limits)
        XCTAssertEqual(missing.violations, [Violation(
            code: .tooLarge, message: "The plan has no overall size, so the size limit can't be checked.", newPart: "overall")])

        let sized = try plan(Fixtures.planBench().newParts, overall: Vector3(x: 400, y: 399, z: 300))
        XCTAssertEqual(try validate(sized, limits: limits).violations, [Violation(
            code: .tooLarge, message: "The build is 400 mm wide; the limit is 300 mm.", newPart: "overall")])
        let allThree = SizeLimits(maxDepthMm: 299, maxHeightMm: 398, maxWidthMm: 400)
        XCTAssertEqual(try validate(sized, limits: allThree).violations.map(\.message), [
            "The build is 399 mm tall; the limit is 398 mm.", "The build is 300 mm deep; the limit is 299 mm.",
        ])
    }

    func testSizeLimitsThatAreMetOrEmpty() throws {
        let sized = try plan(Fixtures.planBench().newParts, overall: Vector3(x: 400, y: 399, z: 300))
        XCTAssertTrue(try validate(sized, limits: SizeLimits(maxDepthMm: 300, maxHeightMm: 399, maxWidthMm: 400)).passes,
                      "exactly at the limit is fine")
        XCTAssertTrue(try validate(Fixtures.planBench(), limits: SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: nil)).passes,
                      "no limits set means nothing to check, even without an overall size")
    }

    // MARK: - Other failure paths

    func testZeroSizeBecomesAViolation() throws {
        let result = try validate(editing("seat") { $0.width = 0 })
        XCTAssertEqual(result.violations, [Violation(
            code: .doesNotFit, message: "seat: width and height must be more than 0 mm.", newPart: "seat")])
    }

    func testBadSpanBecomesASagViolation() throws {
        let result = try validate(editing("seat") { $0.span = 0 })
        XCTAssertEqual(result.violations, [Violation(
            code: .sags, message: "seat: can't check sag: span must be more than 0 mm, got 0.", newPart: "seat")])
    }

    func testNoRoomForBothLegsOnOneSide() throws {
        let result = try validate(editing("leg_right") { $0.source = "side_left" })
        XCTAssertEqual(result.violations.map(\.code), [.doesNotFit])
        XCTAssertEqual(result.violations.first?.newPart, "leg_right")
        XCTAssertEqual(result.violations.first?.message.hasPrefix(
            "leg_right: not enough room left on side_left after its other cuts. Fits with height 160 mm"), true)
    }

    func testManyViolationsAreAllReportedInCheckOrder() throws {
        let inventory = try edited(material: .particleboardMDF, of: "top")
        let parts = [
            EditablePart(name: "ghost", source: "nope", width: 100, height: 100, role: .other),
            EditablePart(name: "seat", source: "top", width: 400, height: 300, role: .seat, span: 360),
            EditablePart(name: "seat", source: "side_left", width: 60, height: 60, role: .other),
            EditablePart(name: "shim", source: "drawer_front", width: 100, height: 100, role: .other),
            EditablePart(name: "big", source: "side_right", width: 453, height: 392, role: .other),
        ].map(\.newPart)
        let result = Validator.validate(plan: plan(parts, overall: Vector3(x: 100, y: 100, z: 200)), inventory: inventory,
                                        limits: SizeLimits(maxDepthMm: 100, maxHeightMm: nil, maxWidthMm: nil))
        XCTAssertEqual(result.violations.map(\.code),
                       [.unknownPart, .partUsedTwice, .damagedPartUsed, .cutNotAllowed, .doesNotFit, .sags, .tooLarge])
        XCTAssertFalse(result.passes)
    }

    // MARK: - Summary numbers

    func testVerifyTiesGoWidthBeforeHeight() {
        let square = Part(damaged: false, heightMm: 400, id: "square", keepOuts: [], material: .solidWood, thicknessMm: 19,
                          type: .top, widthMm: 400)
        let panel = EditablePart(name: "panel", source: "square", width: 300, height: 300, role: .other)
        let result = Validator.validate(plan: plan([panel.newPart]), inventory: Inventory(parts: [square], scanID: "s"),
                                        limits: nil)
        XCTAssertEqual(result.verify.map(\.dimension), [.width, .height])
        XCTAssertEqual(result.verify.map(\.marginMm), [92, 92])
    }

    func testReusePercentEdgeCases() throws {
        let huge = EditablePart(name: "huge", source: "nope", width: 5000, height: 5000, role: .other)
        XCTAssertEqual(try validate(plan([huge.newPart])).reusePercent, 100, "capped at 100")
        let empty = Inventory(parts: [], scanID: "s")
        XCTAssertEqual(Validator.validate(plan: try Fixtures.planBench(), inventory: empty, limits: nil).reusePercent, 0)
        let broken = EditablePart(name: "broken", source: "top", width: -10, height: 10, role: .other)
        XCTAssertEqual(try validate(plan([broken.newPart])).reusePercent, 0, "a negative area counts as nothing")
    }

    func testValidationIsDeterministic() throws {
        let plan = try editing("seat") { $0.width = 453 }
        XCTAssertEqual(try validate(plan), try validate(plan))
    }
}

// MARK: - Helpers: the generated models are immutable, so tests rebuild them with one field changed.

/// A new part with editable fields.
struct EditablePart {
    var name: String
    var source: String
    var width: Double
    var height: Double
    var role: Role
    var span: Double?

    init(name: String, source: String, width: Double, height: Double, role: Role, span: Double? = nil) {
        self.name = name
        self.source = source
        self.width = width
        self.height = height
        self.role = role
        self.span = span
    }

    init(_ part: NewPart) {
        self.init(name: part.name, source: part.sourcePartID, width: part.widthMm, height: part.heightMm,
                  role: part.role, span: part.spanMm)
    }

    var newPart: NewPart {
        let zero = Vector3(x: 0, y: 0, z: 0)
        return NewPart(heightMm: height, name: name, positionMm: zero, role: role, rotationDeg: zero,
                       sourcePartID: source, spanMm: span, widthMm: width)
    }
}

extension ValidatorTests {
    func validate(_ plan: Plan, limits: SizeLimits? = nil) throws -> ValidationResult {
        Validator.validate(plan: plan, inventory: try Fixtures.inventory(), limits: limits)
    }

    func plan(_ parts: [NewPart], template: Template = .bench, overall: Vector3? = nil) -> Plan {
        Plan(hardware: [HardwareItem(item: "wood screw, 40 mm", quantity: 8)], id: "plan-test", newParts: parts,
             overallMm: overall, scanID: "scan-nightstand-1", source: .ginkgo, steps: ["Cut.", "Screw."], template: template)
    }

    /// The sample plan with one new part changed.
    func editing(_ name: String, _ change: (inout EditablePart) -> Void) throws -> Plan {
        let parts = try Fixtures.planBench().newParts.map { part -> NewPart in
            guard part.name == name else { return part }
            var editable = EditablePart(part)
            change(&editable)
            return editable.newPart
        }
        return plan(parts)
    }

    func rename(_ part: NewPart, _ name: String) -> NewPart {
        var editable = EditablePart(part)
        editable.name = name
        return editable.newPart
    }

    /// The sample inventory with one part's material changed.
    func edited(material: Material, of id: String) throws -> Inventory {
        let inventory = try Fixtures.inventory()
        let parts = inventory.parts.map { part in
            part.id != id ? part : Part(damaged: part.damaged, heightMm: part.heightMm, id: part.id, keepOuts: part.keepOuts,
                                        material: material, thicknessMm: part.thicknessMm, type: part.type, widthMm: part.widthMm)
        }
        return Inventory(parts: parts, scanID: inventory.scanID)
    }
}
