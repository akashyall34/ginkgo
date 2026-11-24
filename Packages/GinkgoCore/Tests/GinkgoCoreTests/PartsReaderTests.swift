import Foundation
@testable import GinkgoCore
import XCTest

final class PartsReaderTests: XCTestCase {
    /// The nightstand from examples/inventory.json: 460 wide, 600 tall, 400 deep.
    private let nightstand = Vector3(x: 460, y: 600, z: 400)
    /// The vanity stool prop: 42 × 33 × 44 cm (W × D × H).
    private let stool = Vector3(x: 420, y: 440, z: 330)

    private func part(_ type: TypeEnum, _ box: [Double]?, estimate: [Double], damaged: Bool = false,
                      upholstered: Bool? = nil, curved: Bool? = nil) -> DetectedPart {
        DetectedPart(box2D: box, curved: curved, damaged: damaged, estimatedHeightMm: estimate[1], estimatedWidthMm: estimate[0],
                     material: nil, note: nil, type: type, upholstered: upholstered)
    }

    private func read(_ parts: [DetectedPart], furniture: [Double] = [100, 200, 900, 800],
                      measured: Vector3? = nil) -> (inventory: Inventory, flags: [PartFlag]) {
        PartsReader.inventory(from: PartsReading(furnitureBox2D: furniture, parts: parts), measured: measured ?? nightstand,
                              scanID: "scan-1")
    }

    private func size(_ inventory: Inventory, _ id: String) -> [Double]? {
        inventory.parts.first { $0.id == id }.map { [$0.widthMm, $0.heightMm] }
    }

    private func messages(_ flags: [PartFlag], for id: String) -> [String] {
        flags.filter { $0.partID == id }.map(\.message)
    }

    // MARK: - Known answers (furniture box 600 × 800 units = 460 × 600 mm)

    func testNightstandPartsBecomeMillimetres() {
        let (inventory, flags) = read([
            part(.top, [100, 200, 160, 800], estimate: [460, 400]),
            part(.side, [100, 760, 900, 800], estimate: [400, 600]),
            part(.side, [100, 200, 900, 240], estimate: [400, 600]),
            part(.drawerFront, [300, 230, 500, 770], estimate: [414, 150], damaged: true),
        ])
        XCTAssertEqual(inventory.parts.map(\.id), ["top", "side_left", "drawer_front_1", "side_right"], "ordered left to right")
        XCTAssertEqual(size(inventory, "top"), [460, 400], "a top is width × measured depth")
        XCTAssertEqual(size(inventory, "side_left"), [400, 600], "a side is measured depth × height")
        XCTAssertEqual(size(inventory, "drawer_front_1"), [414, 150])
        XCTAssertEqual(inventory.parts.first { $0.id == "drawer_front_1" }?.damaged, true)
        XCTAssertEqual(messages(flags, for: "drawer_front_1"),
                       ["drawer_front_1: Gemini saw damage. Check it, and mark screw holes or damage as keep-outs."])
        XCTAssertEqual(messages(flags, for: "top"), [], "a good guess isn't flagged")
        XCTAssertEqual(messages(flags, for: "all").count, 2, "material and thickness always need confirming")
        XCTAssertEqual(inventory.scanID, "scan-1")
        XCTAssertEqual(Set(inventory.parts.map(\.thicknessMm)), [18])
        XCTAssertEqual(Set(inventory.parts.map(\.material)), [.solidWood])
    }

    func testGuessesFarFromTheMeasurementAreFlagged() {
        let box: [Double] = [100, 200, 900, 800]   // the whole front: 460 × 600 mm
        let far = read([part(.back, box, estimate: [380, 600])]).flags
        XCTAssertEqual(messages(far, for: "back"),
                       ["back: Gemini guessed 380 × 600 mm, but the photo and the measurement give 460 × 600 mm. Check this."])
        XCTAssertEqual(messages(read([part(.back, box, estimate: [400, 600])]).flags, for: "back"), [], "13% off is fine")
        XCTAssertEqual(messages(read([part(.back, box, estimate: [391, 600])]).flags, for: "back"), [], "exactly 15% is fine")
        XCTAssertEqual(messages(read([part(.back, box, estimate: [460, 700])]).flags, for: "back").count, 1, "height counts too")
    }

    func testHiddenAndUnplaceablePartsUseTheGuessAndSayMeasureIt() {
        let (inventory, flags) = read([
            part(.leg, nil, estimate: [45, 430]),
            part(.rail, [500, 600, 400, 700], estimate: [300, 70]),
            part(.rail, [0, 0, 10, 2000], estimate: [300, 70]),
        ])
        XCTAssertEqual(size(inventory, "leg_1"), [45, 430])
        XCTAssertEqual(inventory.parts.first { $0.id == "leg_1" }?.thicknessMm, 45, "a leg is as thick as it is wide")
        XCTAssertEqual(messages(flags, for: "leg_1"), ["leg_1: not visible in the photo; Gemini guessed 45 × 430 mm. Measure it."])
        XCTAssertEqual(messages(flags, for: "rail_1"),
                       ["rail_1: couldn't place it in the photo; Gemini guessed 300 × 70 mm. Measure it."], "an upside-down box")
        XCTAssertEqual(messages(flags, for: "rail_2").count, 1, "a box past 1000 is unplaceable too")
    }

    func testNoUsableSizeIsSkippedNotInvented() {
        let (inventory, flags) = read([part(.shelf, nil, estimate: [-5, 200]), part(.back, [100, 200, 900, 800], estimate: [460, 600])])
        XCTAssertEqual(inventory.parts.map(\.id), ["back"])
        XCTAssertEqual(messages(flags, for: "shelf_1"), ["shelf_1: couldn't work out its size. Add it by hand."])
    }

    func testMissingFurnitureBoxFallsBackToGuessesForEverything() {
        let (inventory, flags) = read([part(.top, [100, 200, 160, 800], estimate: [450, 390])], furniture: [0, 0, 0, 0])
        XCTAssertEqual(size(inventory, "top"), [450, 390])
        XCTAssertTrue(messages(flags, for: "all").contains {
            $0.hasPrefix("Couldn't find the whole piece in the photo")
        })
        XCTAssertNil(Box2D([1, 2, 3]), "three numbers aren't a box")
        XCTAssertNil(Box2D(nil))
    }

    func testIDsAreDeterministic() {
        XCTAssertEqual(PartsReader.ids(for: [.leg, .leg, .leg, .top, .top, .back, .side, .side, .side]),
                       ["leg_1", "leg_2", "leg_3", "top_1", "top_2", "back", "side_1", "side_2", "side_3"])
    }

    // MARK: - The stool prop (42 × 33 × 44 cm): padded seat, curved legs, rails, hidden parts

    func testStoolReadsHonestly() {
        let (inventory, flags) = read([
            part(.top, [300, 150, 560, 850], estimate: [420, 330], upholstered: true),
            part(.rail, [560, 180, 620, 820], estimate: [380, 70]),
            part(.leg, [560, 180, 950, 260], estimate: [45, 430], curved: true),
            part(.leg, [560, 770, 950, 850], estimate: [45, 430], curved: true),
            part(.leg, nil, estimate: [45, 430], curved: true),
            part(.rail, nil, estimate: [290, 70]),
        ], furniture: [150, 150, 950, 850], measured: stool)
        XCTAssertEqual(inventory.parts.map(\.id), ["top", "rail_1", "leg_1", "leg_2", "leg_3", "rail_2"])
        XCTAssertEqual(size(inventory, "top"), [420, 330])
        XCTAssertEqual(messages(flags, for: "top"), [
            "top: padded: remove the fabric and foam first. If the board underneath is MDF or particleboard, reuse it whole.",
        ])
        let curved = "leg_1: curved: only its straight part can be cut. Measure the straight length."
        XCTAssertTrue(messages(flags, for: "leg_1").contains(curved))
        XCTAssertEqual(messages(flags, for: "leg_3").count, 2, "hidden and curved")
        XCTAssertEqual(messages(flags, for: "rail_1").count, 1, "a photo taken from above squashes the rail: flagged, not trusted")
        XCTAssertFalse(inventory.parts.contains { $0.type == .side }, "no sides are invented for a stool")
    }

    // MARK: - Request and parsing

    func testRequestCarriesPromptMeasurementPhotoAndSchema() throws {
        let photo = Data([0xFF, 0xD8, 0xFF, 0x00])
        let body = PartsReader.request(photo: photo, mimeType: "image/jpeg", measured: stool)
        let parts = try XCTUnwrap(body["contents"]?.arrayValue?.first?["parts"]?.arrayValue)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0]["text"]?.stringValue?.hasSuffix("Measured size: 420 mm wide, 440 mm tall, 330 mm deep."), true)
        XCTAssertEqual(parts[1]["inlineData"], ["mimeType": "image/jpeg", "data": .string(photo.base64EncodedString())])
        XCTAssertEqual(body["generationConfig"]?["responseMimeType"], "application/json")
        XCTAssertEqual(body["generationConfig"]?["responseSchema"]?["required"], ["furniture_box_2d", "parts"])
        XCTAssertEqual(body["generationConfig"]?["thinkingConfig"], ["thinkingLevel": "low"])
        let plain = PartsReader.request(photo: photo, mimeType: "image/png", measured: stool, thinkingLevel: nil)
        XCTAssertNil(plain["generationConfig"]?["thinkingConfig"])
        XCTAssertNil(body["tools"], "no tools: one structured answer")
    }

    func testParseReadsGeminisJSONAndRejectsGarbage() throws {
        let text = #"{"furniture_box_2d": [100, 200, 900, 800], "parts": [{"type": "rail", "damaged": false, "#
            + #""estimated_width_mm": 380, "estimated_height_mm": 70, "box_2d": [560, 180, 620, 820], "curved": false}]}"#
        let reading = try PartsReader.parse(text)
        XCTAssertEqual(reading.parts.first?.type, .rail)
        XCTAssertEqual(reading.parts.first?.box2D, [560, 180, 620, 820])
        XCTAssertNil(reading.parts.first?.upholstered)
        XCTAssertThrowsError(try PartsReader.parse("I see a stool."))
        XCTAssertThrowsError(try PartsReader.parse(#"{"parts": []}"#))
    }

    func testANightstandReadingFeedsTheFallbackPlanner() throws {
        let (inventory, _) = read([
            part(.top, [100, 200, 160, 800], estimate: [460, 400]),
            part(.side, [100, 200, 900, 240], estimate: [400, 600]),
            part(.side, [100, 760, 900, 800], estimate: [400, 600]),
        ])
        // Gemini's material is a guess, so it is rated as particleboard: no bench until the person confirms.
        XCTAssertNotEqual(RuleBasedPlanner.bench(inventory: inventory)?.plan.template, .bench)
        let confirmed = Inventory(parts: inventory.parts.map { $0.with(grain: .alongWidth, materialSource: .confirmed) },
                                  scanID: inventory.scanID)
        let result = try XCTUnwrap(RuleBasedPlanner.bench(inventory: confirmed))
        XCTAssertTrue(result.validation.passes)
        XCTAssertEqual(result.plan.template, .bench)
    }
}
