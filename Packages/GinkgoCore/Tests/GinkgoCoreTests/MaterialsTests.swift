@testable import GinkgoCore
import XCTest

/// Ginkgo works with more than wood: only solid wood and plywood are cut; everything else is reused whole.
/// The prop shapes come from the team's tape measurements (plastic 3-drawer cart 31.5 × 36.5 × 60 cm,
/// cardboard box 31.5 × 41 × 31 cm).
final class MaterialsTests: XCTestCase {
    private func part(_ id: String, _ type: TypeEnum, _ size: [Double], _ material: Material, thickness: Double) -> Part {
        Part(damaged: false, heightMm: size[1], id: id, keepOuts: [], material: material, thicknessMm: thickness,
             type: type, widthMm: size[0])
    }

    /// The plastic 3-drawer cart: top, two frame sides, three drawers.
    private var drawerCart: Inventory {
        Inventory(parts: [
            part("top", .top, [315, 365], .plastic, thickness: 20),
            part("side_left", .side, [365, 600], .plastic, thickness: 3),
            part("side_right", .side, [365, 600], .plastic, thickness: 3),
            part("drawer_1", .drawerBox, [290, 170], .plastic, thickness: 2),
            part("drawer_2", .drawerBox, [290, 170], .plastic, thickness: 2),
            part("drawer_3", .drawerBox, [290, 170], .plastic, thickness: 2),
        ], scanID: "scan-drawer-cart")
    }

    /// The cardboard box: top flaps, two long sides, two ends, bottom.
    private var box: Inventory {
        Inventory(parts: [
            part("top", .top, [410, 315], .cardboard, thickness: 4),
            part("side_left", .side, [410, 310], .cardboard, thickness: 4),
            part("side_right", .side, [410, 310], .cardboard, thickness: 4),
            part("back", .back, [315, 310], .cardboard, thickness: 4),
        ], scanID: "scan-box")
    }

    private func newPart(_ name: String, _ source: String, _ size: [Double], _ role: Role, span: Double? = nil) -> NewPart {
        let zero = Vector3(x: 0, y: 0, z: 0)
        return NewPart(heightMm: size[1], name: name, positionMm: zero, role: role, rotationDeg: zero, sourcePartID: source,
                       spanMm: span, widthMm: size[0])
    }

    private func plan(_ parts: [NewPart], _ template: Template = .bench) -> Plan {
        Plan(hardware: [], id: "p", newParts: parts, overallMm: nil, scanID: "s", source: .chatbot, steps: [], template: template)
    }

    func testOnlyWoodAndPlywoodCanBeCut() {
        XCTAssertEqual([Material.solidWood, .plywood, .particleboardMDF, .plastic, .cardboard].map(\.canBeCut),
                       [true, true, false, false, false])
        XCTAssertEqual(Material.plastic.displayName, "plastic")
        XCTAssertEqual(Material.particleboardMDF.displayName, "particleboard/MDF")
        XCTAssertEqual(Material.solidWood.displayName, "solid wood")
        XCTAssertEqual(Material.plywood.displayName, "plywood")
        XCTAssertEqual(Material.cardboard.whyNotCut, "is too weak to cut into furniture parts")
        XCTAssertEqual(Material.plywood.whyNotCut, "can be cut")
        XCTAssertNil(Sag.stiffness(of: .plastic), "no sourced stiffness, so no number at all")
        XCTAssertNil(Sag.stiffness(of: .cardboard))
        XCTAssertEqual(MaterialCatalog.all.filter(\.loadBearing).map(\.material), [.solidWood, .plywood, .particleboardMDF])
    }

    func testEveryNumberHasASourceAndACheckDate() {
        for info in MaterialCatalog.all {
            XCTAssertFalse(info.source.isEmpty, "\(info.material)")
            XCTAssertTrue(info.checked.contains("2026-11-21"), "\(info.material) says when it was checked")
        }
        XCTAssertTrue(MaterialCatalog.info(.solidWood).source.contains("FPL-GTR-282 (2021)"))
        XCTAssertTrue(MaterialCatalog.info(.particleboardMDF).source.contains("ANSI A208.1-2022"))
    }

    func testPlasticCanNeverBeAShelfAndNoSagNumberIsShown() {
        let shelf = newPart("shelf", "drawer_1", [290, 170], .shelf, span: 290)
        let result = Validator.validate(plan: plan([shelf], .noCut), inventory: drawerCart, limits: nil)
        XCTAssertEqual(result.violations.map(\.message),
                       ["shelf: drawer_1 is plastic, which isn't load-bearing, so it can't be a seat or shelf."])
        XCTAssertEqual(result.sag, [], "no unsourced sag number reaches the screen")
        let check = ToolExecutor(inventory: drawerCart, limits: nil).run(ToolCall(name: "check_sag", args: ["items": [
            ["new_part": "shelf", "source_part_id": "drawer_1", "role": "shelf", "span_mm": 290, "depth_mm": 170],
        ]]), index: 0)
        XCTAssertEqual(check.step.summary, "shelf: drawer_1 is plastic, which isn't load-bearing, so it can't be a seat or shelf")
        XCTAssertNil(check.result.response["results"]?.arrayValue?.first?["deflection_mm"])
    }

    func testCuttingTheDrawerCartIsNotAllowed() {
        let result = Validator.validate(plan: plan([newPart("shelf", "top", [300, 300], .other)]), inventory: drawerCart, limits: nil)
        XCTAssertEqual(result.violations.map(\.code), [.cutNotAllowed])
        XCTAssertEqual(result.violations.first?.message,
                       "shelf: top is plastic, which has thin walls that crack or warp when sawn. "
                        + "Reuse it whole (315 × 365 mm) instead of cutting 300 × 300 mm.")
    }

    func testDrawersReusedWholeAreFine() {
        let cubbies = [newPart("cubby_1", "drawer_1", [290, 170], .other), newPart("cubby_2", "drawer_2", [290, 170], .other)]
        XCTAssertTrue(Validator.validate(plan: plan(cubbies, .noCut), inventory: drawerCart, limits: nil).passes)
    }

    func testCardboardCanNeverBeASeat() {
        let seat = newPart("seat", "top", [410, 315], .seat, span: 380)
        let result = Validator.validate(plan: plan([seat], .noCut), inventory: box, limits: nil)
        XCTAssertEqual(result.violations, [Violation(
            code: .sags, message: "seat: top is cardboard, which isn't load-bearing, so it can't be a seat or shelf.",
            newPart: "seat")], "reusing it whole is allowed, but never as a seat")
        XCTAssertEqual(result.sag, [])
    }

    func testFallbackReusesThePlasticCartWholeWithCableTies() throws {
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: drawerCart))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .noCut)
        XCTAssertEqual(plan.newParts.count, 6)
        XCTAssertEqual(plan.hardware, [HardwareItem(item: "cable tie, 200 mm", quantity: 10)])
        XCTAssertEqual(plan.steps.last, "If you want them to stay together, join each neighbouring pair with 2 of: cable tie, 200 mm.")
    }

    func testFallbackReusesTheBoxWholeWithTape() throws {
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: box))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .noCut)
        XCTAssertEqual(plan.hardware.first?.item, "double-sided mounting tape strip")
    }

    func testCheckFitSaysWhichMaterialCantBeCut() {
        let tool = ToolExecutor(inventory: drawerCart, limits: nil)
        let call = ToolCall(name: "check_fit", args: ["placements": [
            ["new_part": "shelf", "source_part_id": "top", "width_mm": 300, "height_mm": 300],
        ]])
        let outcome = tool.run(call, index: 0)
        XCTAssertEqual(outcome.step.summary, "shelf from top: plastic can't be cut")
        XCTAssertEqual(outcome.result.response["results"]?.arrayValue?.first?["blocked_by"], "plastic")
    }

    func testPartsReaderKeepsGeminisMaterialGuess() {
        let guessed = DetectedPart(box2D: [100, 200, 900, 800], curved: nil, damaged: false, estimatedHeightMm: 600,
                                   estimatedWidthMm: 315, material: .plastic, note: nil, type: .back, upholstered: nil)
        let unknown = DetectedPart(box2D: nil, curved: nil, damaged: false, estimatedHeightMm: 170, estimatedWidthMm: 290,
                                   material: nil, note: nil, type: .drawerBox, upholstered: nil)
        let (inventory, _) = PartsReader.inventory(from: PartsReading(furnitureBox2D: [100, 200, 900, 800], parts: [guessed, unknown]),
                                                  measured: Vector3(x: 315, y: 600, z: 365), scanID: "s")
        XCTAssertEqual(inventory.parts.map(\.material), [.plastic, .solidWood], "no guess means solid wood, flagged for the user")
        XCTAssertEqual(inventory.parts.map(\.thicknessMm), [3, 18], "a typical thickness for each material")
        XCTAssertEqual(MaterialCatalog.info(.cardboard).typicalThicknessMm, 4)
    }
}
