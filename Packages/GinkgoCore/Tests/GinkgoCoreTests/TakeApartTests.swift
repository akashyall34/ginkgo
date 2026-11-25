import XCTest
@testable import GinkgoCore

final class TakeApartTests: XCTestCase {
    private func part(_ id: String, _ type: TypeEnum) -> Part {
        Part(damaged: false, heightMm: 300, id: id, keepOuts: [], material: .solidWood, thicknessMm: 18, type: type,
             widthMm: 400)
    }

    private var inventory: Inventory {
        Inventory(parts: [part("top", .top), part("side_left", .side), part("side_right", .side), part("back", .back),
                          part("drawer_front", .drawerFront)], scanID: "s")
    }

    private func step(_ ids: [String], _ action: String = "Undo it.", _ fastener: Fastener = .screws)
        -> TakeApartReading.Step {
        TakeApartReading.Step(partIDs: ids, action: action, fastener: fastener)
    }

    // MARK: - Template (no network)

    func testWithNoReadingTheTemplateCoversEveryPartInAWorkableOrder() {
        let guide = TakeApart.guide(nil, inventory: inventory)
        XCTAssertEqual(guide.source, .template)
        XCTAssertEqual(guide.steps.first?.action, TakeApart.safetyStep)
        XCTAssertEqual(guide.steps.first?.tools, "", "The safety step needs no tools line")
        XCTAssertEqual(guide.steps.dropFirst().flatMap(\.partIDs), ["drawer_front", "back", "top", "side_left", "side_right"])
        XCTAssertEqual(guide.steps.map(\.number), [1, 2, 3, 4, 5, 6])
        XCTAssertTrue(guide.steps.allSatisfy { !$0.fromGemini })
    }

    func testAnEmptyReadingIsTheTemplate() {
        XCTAssertEqual(TakeApart.guide(TakeApartReading(steps: []), inventory: inventory).source, .template)
    }

    func testTemplateWordsNameThePart() {
        let guide = TakeApart.template(inventory)
        XCTAssertEqual(guide.steps[1].action, "Pull the drawer front all the way out and lift it off its runners.")
        XCTAssertTrue(guide.steps[4].action.contains("left side"), guide.steps[4].action)
    }

    // MARK: - Gemini's steps, checked

    func testGeminisStepsAreKeptInItsOrderWithCodeChosenTools() {
        let reading = TakeApartReading(steps: [
            step(["drawer_front"], "Pull the drawer out.", .clips),
            step(["back"], "Pull the nails.", .nails),
            step(["top"], "Undo four screws.", .screws),
            step(["side_left", "side_right"], "Turn the cam locks.", .camLocks),
        ])
        let guide = TakeApart.guide(reading, inventory: inventory)
        XCTAssertEqual(guide.source, .gemini)
        XCTAssertEqual(guide.notes, [])
        XCTAssertEqual(guide.steps.map(\.action),
                       [TakeApart.safetyStep, "Pull the drawer out.", "Pull the nails.", "Undo four screws.", "Turn the cam locks."])
        XCTAssertEqual(guide.steps[2].tools, TakeApart.tools(for: .nails))
        XCTAssertTrue(guide.steps[2].tools.hasPrefix("Pry bar"))
        XCTAssertTrue(guide.steps.dropFirst().allSatisfy(\.fromGemini))
    }

    func testAStepNamingAPartNotInTheListIsLeftOutAndSaid() {
        let reading = TakeApartReading(steps: [step(["door"]), step(["top", "mirror"]),
                                               step(["top"]), step(["side_left", "side_right", "back", "drawer_front"])])
        let guide = TakeApart.guide(reading, inventory: inventory)
        XCTAssertEqual(guide.steps.count, 3)
        XCTAssertEqual(guide.notes, ["Ginkgo left out 2 steps that named parts not in your list."])
    }

    func testOneBadStepSaysSoInTheSingular() {
        let reading = TakeApartReading(steps: [step(["door"]), step(["top", "side_left", "side_right", "back", "drawer_front"])])
        XCTAssertEqual(TakeApart.guide(reading, inventory: inventory).notes,
                       ["Ginkgo left out 1 step that named a part not in your list."])
    }

    func testABlankActionIsLeftOut() {
        let reading = TakeApartReading(steps: [step(["top"], "   "), step(["top", "side_left", "side_right", "back", "drawer_front"])])
        XCTAssertEqual(TakeApart.guide(reading, inventory: inventory).steps.count, 2)
    }

    func testEveryPartGeminiSkippedGetsAStandardStepInOrder() {
        let reading = TakeApartReading(steps: [step(["top"], "Lift the top.")])
        let guide = TakeApart.guide(reading, inventory: inventory)
        XCTAssertEqual(guide.steps.dropFirst().flatMap(\.partIDs), ["top", "drawer_front", "back", "side_left", "side_right"])
        XCTAssertEqual(guide.steps.filter { !$0.fromGemini }.count, 5, "Safety plus four added steps")
        XCTAssertEqual(guide.notes.first,
                       "Gemini didn't say how the drawer front comes off, so Ginkgo added a standard step.")
        XCTAssertEqual(guide.notes.count, 4)
    }

    func testIfNoStepSurvivesTheTemplateIsUsedAndSaysWhy() {
        let guide = TakeApart.guide(TakeApartReading(steps: [step(["door"])]), inventory: inventory)
        XCTAssertEqual(guide.source, .template)
        XCTAssertEqual(guide.notes.first, "Ginkgo left out 1 step that named a part not in your list.")
        XCTAssertEqual(guide.steps.count, 6)
    }

    func testGlueAddsTheScanWarning() {
        let reading = TakeApartReading(steps: [step(["top", "side_left", "side_right", "back", "drawer_front"], "Pry.", .glue)])
        let guide = TakeApart.guide(reading, inventory: inventory)
        XCTAssertTrue(guide.notes.contains { $0.hasPrefix("Glued joints") })
        XCTAssertFalse(TakeApart.guide(TakeApartReading(steps: [step(["top", "side_left", "side_right", "back", "drawer_front"])]),
                                       inventory: inventory).notes.contains { $0.hasPrefix("Glued") })
    }

    func testTooManyStepsAreCapped() {
        let many = Array(repeating: step(["top", "side_left", "side_right", "back", "drawer_front"]), count: 25)
        let guide = TakeApart.guide(TakeApartReading(steps: many), inventory: inventory)
        XCTAssertEqual(guide.steps.count, TakeApart.maxSteps + 1)
        XCTAssertEqual(guide.notes, ["Gemini gave more than 20 steps; only the first 20 were kept."])
    }

    // MARK: - Wire

    func testParsingAcceptsAnUnknownFastenerWordAsUnknown() throws {
        let json = #"{"steps":[{"part_ids":["top"],"action":"Lift it.","fastener":"velcro"}]}"#
        XCTAssertEqual(try TakeApart.parse(json).steps.first?.fastener, .unknown)
    }

    func testParsingRejectsAnAnswerWithoutSteps() {
        XCTAssertThrowsError(try TakeApart.parse(#"{"order":[]}"#))
    }

    func testThePromptListsEveryPartID() {
        let prompt = TakeApart.prompt(for: inventory)
        for id in ["top", "side_left", "side_right", "back", "drawer_front"] { XCTAssertTrue(prompt.contains("- \(id):"), id) }
    }

    func testEveryFastenerHasDistinctTools() {
        let tools = Fastener.allCases.map(TakeApart.tools(for:))
        XCTAssertFalse(tools.contains(where: \.isEmpty))
        XCTAssertEqual(Set(tools.dropLast(0)).count, tools.count - 1, "Nails and staples share a tool line")
    }

    func testTemplateOrderCoversEveryType() {
        let all: [TypeEnum] = [.leg, .side, .rail, .top, .back, .shelf, .drawerBox]
        let parts = all.enumerated().map { part("p\($0.offset)", $0.element) }
        XCTAssertEqual(TakeApart.ordered(parts).map(\.type), [.drawerBox, .shelf, .back, .top, .rail, .side, .leg])
        XCTAssertTrue(parts.allSatisfy { !TakeApart.templateAction($0).isEmpty })
    }
}
