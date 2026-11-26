@testable import GinkgoCore
import XCTest

/// The less usual inputs: repeated ids, missing source panels, empty lists and bad JSON. Each test says what the code
/// should do with them, and together they keep every line of the logic exercised.
final class EdgeCaseTests: XCTestCase {
    // MARK: - Helpers

    private func part(_ id: String, _ type: TypeEnum = .side, width: Double = 400, height: Double = 300,
                      thickness: Double = 18, material: Material = .plywood, keepOuts: [Rect] = []) -> Part {
        Part(damaged: false, heightMm: height, id: id, keepOuts: keepOuts, material: material, materialSource: .confirmed,
             thicknessMm: thickness, thicknessSource: .tape, type: type, widthMm: width)
    }

    private func newPart(_ name: String, from source: String, _ role: Role, x: Double = 0, width: Double = 300,
                         height: Double = 200) -> NewPart {
        NewPart(heightMm: height, name: name, positionMm: Vector3(x: x, y: 0, z: 0), role: role,
                rotationDeg: Vector3(x: 0, y: 0, z: 0), sourcePartID: source, spanMm: nil, widthMm: width)
    }

    private func plan(_ parts: [NewPart], template: Template = .bench) -> Plan {
        Plan(hardware: [], id: "p", newParts: parts, overallMm: nil, scanID: "s", source: .ginkgo, steps: [], template: template)
    }

    // MARK: - Repeated ids

    func testARepeatedPartIdKeepsTheFirstPart() {
        let inventory = Inventory(parts: [part("a", thickness: 12), part("a", thickness: 30), part("b")], scanID: "s")
        XCTAssertEqual(inventory.partsByID["a"]?.thicknessMm, 12)
        XCTAssertEqual(inventory.partsByID.count, 2)
    }

    // MARK: - Overhang

    func testAnUnknownSourcePanelCountsAsZeroThick() {
        let footprint = Overhang.footprint(newPart("leg", from: "nowhere", .support, width: 100, height: 200), parts: [:])
        XCTAssertEqual(footprint.minX, -50)
        XCTAssertEqual(footprint.maxX, 50)
        XCTAssertEqual(footprint.minZ, 0, "No thickness to stand on")
    }

    func testAPlanWithNoUprightsHasNothingToTip() {
        let seat = newPart("seat", from: "a", .seat)
        XCTAssertEqual(Overhang.violations(plan([seat]), parts: ["a": part("a")], placed: ["seat"]), [])
    }

    // MARK: - Assembly guide

    func testAnUprightWhosePanelIsMissingGetsAWarningAndNoBrackets() {
        let inventory = Inventory(parts: [part("top", .top, thickness: 25)], scanID: "s")
        let guide = AssemblyGuide.guide(for: plan([newPart("seat", from: "top", .seat),
                                                   newPart("leg", from: "gone", .support)]), inventory: inventory)
        XCTAssertEqual(guide.warnings.count, 1)
        XCTAssertTrue(guide.warnings[0].contains("too thin"), guide.warnings[0])
        XCTAssertEqual(guide.hardware, [], "No joint could take a bracket, so none is listed")
        XCTAssertTrue(guide.steps.last?.text.hasPrefix("Turn it over onto its support.") ?? false, "One support, singular")
    }

    func testTwoThicknessesNeedTwoScrewSizesListedInOrder() {
        let inventory = Inventory(parts: [part("top", .top, thickness: 25), part("a", thickness: 18),
                                          part("b", thickness: 19)], scanID: "s")
        let guide = AssemblyGuide.guide(for: plan([newPart("seat", from: "top", .seat),
                                                   newPart("leg_left", from: "a", .support, x: -100),
                                                   newPart("leg_right", from: "b", .support, x: 100)]),
                                        inventory: inventory)
        let screws = guide.hardware.filter { $0.item.hasPrefix("wood screw") }.map(\.item)
        XCTAssertEqual(screws.count, 2)
        XCTAssertEqual(screws, screws.sorted(), "Listed in a steady order")
        XCTAssertTrue(guide.hardware.contains { $0.item.contains("bracket") })
        XCTAssertTrue(guide.steps.last?.text.hasPrefix("Turn it over onto its supports.") ?? false)
    }

    func testRepeatedPanelIdsInTheInventoryUseTheFirst() {
        let inventory = Inventory(parts: [part("top", .top, thickness: 25), part("a", thickness: 18),
                                          part("a", thickness: 5)], scanID: "s")
        let guide = AssemblyGuide.guide(for: plan([newPart("seat", from: "top", .seat),
                                                   newPart("leg", from: "a", .support)]), inventory: inventory)
        XCTAssertEqual(guide.warnings, [], "The 18 mm panel counts, not the 5 mm one")
    }

    // MARK: - Prompts

    func testAnInventoryThatCantBeWrittenAsJSONSendsAnEmptyOne() {
        let broken = Inventory(parts: [part("a", width: .nan)], scanID: "s")
        let prompt = Prompts.plannerUser(inventory: broken, limits: nil, request: "")
        XCTAssertTrue(prompt.contains("{}"), prompt)
    }

    // MARK: - JSON

    func testAValueThatIsNotJSONIsRejected() throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["when": Date()], format: .xml, options: 0)
        XCTAssertThrowsError(try PropertyListDecoder().decode(JSON.self, from: plist))
    }

    func testAnEncoderThatFailsGivesNull() {
        final class Failing: JSONEncoder, @unchecked Sendable {
            override func encode<T: Encodable>(_ value: T) throws -> Data { throw CocoaError(.coderInvalidValue) }
        }
        XCTAssertEqual(JSON.string("x").encodedString(using: Failing()), "null")
        XCTAssertThrowsError(try JSON.string("x").encodedData(using: Failing()))
    }

    func testARepeatedKeyInAnObjectLiteralKeepsTheLast() {
        let json = JSON(dictionaryLiteral: ("a", 1), ("a", 2))
        XCTAssertEqual(json.objectValue?["a"], .number(2))
    }

    // MARK: - Materials

    func testEveryMaterialHasItsOwnEntry() {
        for material in [Material.solidWood, .plywood, .particleboardMDF, .plastic, .cardboard] {
            XCTAssertEqual(MaterialCatalog.info(material).material, material)
        }
    }

    // MARK: - Layout

    private func draft(_ template: Template, _ parts: [(String, Role)]) -> PlanDraft {
        PlanDraft(hardware: [], newParts: parts.map { DraftPart(heightMm: 300, name: $0.0, role: $0.1, sourcePartID: "a",
                                                                spanMm: nil, widthMm: 400) },
                  steps: [], template: template)
    }

    func testABookshelfWithOnlyShelvesStillLaysOut() {
        let inventory = Inventory(parts: [part("a")], scanID: "s")
        let plan = Layout.plan(from: draft(.bookshelf, [("shelf", .shelf)]), inventory: inventory, id: "p")
        XCTAssertEqual(plan.newParts.map(\.name), ["shelf"])
    }

    func testABookshelfWithOnlySidesStillLaysOut() {
        let inventory = Inventory(parts: [part("a")], scanID: "s")
        let plan = Layout.plan(from: draft(.bookshelf, [("side", .side)]), inventory: inventory, id: "p")
        XCTAssertEqual(plan.newParts.map(\.name), ["side"])
    }

    // MARK: - Rule-based planner

    func testNoSupportPanelsMeansNoSupportSize() {
        XCTAssertNil(RuleBasedPlanner.supportSize(on: [], seatDepth: 300))
    }

    func testALegShortensUntilItClearsAKeepOutBand() throws {
        let band = Rect(heightMm: 30, widthMm: 200, xMm: 0, yMm: 400)
        let side = part("s", width: 200, height: 500, keepOuts: [band])
        let size = try XCTUnwrap(RuleBasedPlanner.supportSize(on: [side, side], seatDepth: 300))
        XCTAssertEqual(size.width, 192)
        XCTAssertEqual(size.height, 390, "Shortened 10 mm at a time from 420 until it fits under the band")
    }

    func testSupportsThickerThanTheSeatIsWideMakeNoBenchDraftAndTheRulesReusePanelsWhole() throws {
        let parts = [part("top", .top, width: 400, height: 300),
                     part("s1", .side, width: 300, height: 400, thickness: 300),
                     part("s2", .side, width: 300, height: 400, thickness: 300)]
        XCTAssertNil(RuleBasedPlanner.benchDraft(from: parts), "No room between supports that thick")
        let fallback = try XCTUnwrap(RuleBasedPlanner.bench(inventory: Inventory(parts: parts, scanID: "s")))
        XCTAssertEqual(fallback.plan.template, .noCut, "The panels are reused whole instead")
    }

    // MARK: - More assembly and fit

    func testASeatWhosePanelIsMissingWarnsInsteadOfGuessing() {
        let inventory = Inventory(parts: [part("a", thickness: 18)], scanID: "s")
        let guide = AssemblyGuide.guide(for: plan([newPart("seat", from: "gone", .seat),
                                                   newPart("leg", from: "a", .support)]), inventory: inventory)
        XCTAssertEqual(guide.warnings.count, 1, "A missing seat panel counts as zero thick: too thin for a bracket screw")
    }

    func testAPlacedPlanWithAnEmptyPackResultReportsASizeProblem() throws {
        let executor = ToolExecutor(inventory: try Fixtures.inventory(), limits: nil)
        let source = try XCTUnwrap(try Fixtures.inventory().parts.first)
        let empty = PackResult(sourcePartID: source.id, placements: [], failures: [], spareWidthMm: 0, spareHeightMm: 0)
        let row = executor.fitRow(FitRequest(name: "seat", source: source.id, width: 100, height: 100), number: 0,
                                  part: source, pack: empty)
        XCTAssertFalse(row.passes)
        XCTAssertEqual(row.json["blocked_by"]?.stringValue, "invalid_size", "A cut with no result is reported, not lost")
    }

    func testEqualMarginsOnOneSourceListWidthBeforeHeight() {
        let pack = PackResult(sourcePartID: "a", placements: [Placement(heightMm: 10, newPart: "x", rotated: false,
                                                                        sourcePartID: "a", widthMm: 10, xMm: 0, yMm: 0)],
                              failures: [], spareWidthMm: 5, spareHeightMm: 5)
        XCTAssertEqual(Validator.verifyItems([pack]).map(\.dimension), [.width, .height])
    }

    func testRepeatedPanelIdsAreCheckedOnce() throws {
        let inventory = Inventory(parts: [part("a", width: 460, height: 400), part("a", width: 460, height: 400)],
                                  scanID: "s")
        let result = Validator.validate(plan: plan([newPart("cut", from: "a", .other, width: 300, height: 200)]),
                                        inventory: inventory, limits: nil)
        XCTAssertEqual(result.placements.count, 1, "The second copy of the id isn't packed again")
    }

    // MARK: - Gemini wire

    func testRepeatedSchemaPropertyNamesKeepTheFirst() {
        let schema = ParamSchema.object([ParamProperty(name: "a", schema: .string("first")),
                                         ParamProperty(name: "a", schema: .number("second"))], "obj")
        let fields = GeminiWire.schema(schema)["properties"]?.objectValue
        XCTAssertEqual(fields?.count, 1)
        XCTAssertEqual(fields?["a"]?["type"]?.stringValue, "STRING")
    }

    func testACallWithNoNameBecomesAnEmptyName() throws {
        let response: JSON = ["candidates": [["content": ["role": "model", "parts": [["functionCall": [:]]]]]]]
        let turn = try GeminiWire.parse(response: response).turn
        XCTAssertEqual(turn.calls.map(\.name), [""])
    }

    // MARK: - Take-apart

    func testAStepWithNoFastenerIsUnknown() throws {
        let reading = try TakeApart.parse(#"{"steps":[{"part_ids":["top"],"action":"Lift it."}]}"#)
        XCTAssertEqual(reading.steps.first?.fastener, .unknown)
    }

    func testTheTakeApartSchemaListsEveryFastener() throws {
        let json = GeminiWire.schema(TakeApart.responseSchema)
        let steps = try XCTUnwrap(json["properties"]?["steps"]?["items"]?["properties"])
        let values = steps["fastener"]?["enum"]?.arrayValue?.compactMap(\.stringValue)
        XCTAssertEqual(values, Fastener.allCases.map(\.rawValue))
    }

    func testAFailureForAPartNotInThePlanIsListedFirst() {
        let source = part("a")
        let ghost = Packer.invalidFailure(CutRequest(name: "ghost", widthMm: 0, heightMm: 10), source: source)
        let real = Packer.invalidFailure(CutRequest(name: "real", widthMm: 0, heightMm: 10), source: source)
        let inPlan = plan([newPart("first", from: "a", .other), newPart("real", from: "a", .other)])
        for failures in [[real, ghost], [ghost, real]] {
            let pack = PackResult(sourcePartID: "a", placements: [], failures: failures, spareWidthMm: 0, spareHeightMm: 0)
            let violations = Validator.fitViolations(inPlan, packs: [pack], parts: ["a": source])
            XCTAssertEqual(violations.map(\.newPart), ["ghost", "real"], "Whatever order they arrive in")
        }
    }
}
