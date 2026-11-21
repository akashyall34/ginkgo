import FirebaseAILogic
import GinkgoCore
import XCTest
@testable import Ginkgo

@MainActor
final class PartsStepTests: XCTestCase {
    private let box = FittedBox(length: 0.41, width: 0.315, height: 0.31, baseCenter: .zero, yaw: 0, uncertainty: 0.01,
                                pointCount: 4000)
    private let photo = Data([0xFF, 0xD8, 0xFF])
    /// A Gemini answer shaped like PartsReader.responseSchema: a top and two sides.
    private let answer = #"{"furniture_box_2d": [100, 100, 900, 900], "parts": ["#
        + #"{"type": "top", "damaged": false, "estimated_width_mm": 400, "estimated_height_mm": 300, "box_2d": [100, 100, 180, 900]},"#
        + #"{"type": "side", "damaged": false, "estimated_width_mm": 300, "estimated_height_mm": 290, "box_2d": [180, 100, 900, 160]},"#
        + #"{"type": "side", "damaged": true, "estimated_width_mm": 300, "estimated_height_mm": 290, "box_2d": [180, 840, 900, 900]}]}"#

    func testTheMeasuredSizeIsLengthAcrossHeightUpWidthDeep() {
        XCTAssertEqual(PartsStep.measured(box), Vector3(x: 410, y: 310, z: 315))
        let prompt = PartsStep.prompt(for: PartsStep.measured(box))
        XCTAssertTrue(prompt.hasPrefix(PartsReader.prompt))
        XCTAssertTrue(prompt.hasSuffix("Measured size: 410 mm wide, 310 mm tall, 315 mm deep."))
    }

    func testGeminisAnswerBecomesTheParts() async {
        var sent: (String, Data)?
        let result = await PartsStep.read(photo: photo, box: box, scanID: "scan-1") { prompt, image in
            sent = (prompt, image)
            return self.answer
        }
        XCTAssertTrue(result.fromGemini)
        XCTAssertEqual(sent?.1, photo, "The photo is what Gemini reads")
        XCTAssertTrue(sent?.0.contains("410 mm wide") ?? false)
        XCTAssertEqual(result.inventory.scanID, "scan-1")
        XCTAssertEqual(result.inventory.parts.map(\.type), [.top, .side, .side])
        XCTAssertEqual(result.inventory.parts.filter(\.damaged).count, 1)
        XCTAssertFalse(result.flags.isEmpty, "Material and thickness always need confirming")
    }

    func testNoConnectionFallsBackToTheBoxEstimateAndSaysSo() async {
        struct Offline: Error {}
        let result = await PartsStep.read(photo: photo, box: box, scanID: "s") { _, _ in throw Offline() }
        XCTAssertFalse(result.fromGemini)
        XCTAssertEqual(result.inventory.parts.map(\.id), ["top", "side_left", "side_right"])
        XCTAssertEqual(result.flags.map(\.message), [PartsStep.offlineMessage])
    }

    func testAnUnreadableAnswerFallsBack() async {
        let result = await PartsStep.read(photo: photo, box: box, scanID: "s") { _, _ in "I see a box." }
        XCTAssertFalse(result.fromGemini)
    }

    func testAnAnswerWithNoPartsFallsBack() async {
        let empty = #"{"furniture_box_2d": [100, 100, 900, 900], "parts": []}"#
        let result = await PartsStep.read(photo: photo, box: box, scanID: "s") { _, _ in empty }
        XCTAssertFalse(result.fromGemini)
    }

    func testNoPhotoNeverCallsGemini() async {
        var called = false
        let result = await PartsStep.read(photo: nil, box: box, scanID: "s") { _, _ in called = true; return self.answer }
        XCTAssertFalse(called)
        XCTAssertFalse(result.fromGemini)
    }

    func testPickingAMaterialChangesOnlyThatPart() {
        let inventory = LivePlan.inventory(from: box, scanID: "s")
        let changed = PartsStep.setting(.plywood, of: "top", in: inventory)
        XCTAssertEqual(changed.parts.map(\.material), [.plywood, .solidWood, .solidWood])
    }
}

final class GeminiSchemaTests: XCTestCase {
    /// The schema Gemini gets must match the one Vivek's parser expects, field for field.
    func testThePartsSchemaKeepsEveryFieldEnumAndOptionalOne() throws {
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(GeminiSchema.firebase(PartsReader.responseSchema)),
                                        encoding: .utf8))
        for name in ["furniture_box_2d", "parts", "type", "box_2d", "damaged", "upholstered", "curved",
                     "estimated_width_mm", "estimated_height_mm", "note"] {
            XCTAssertTrue(json.contains("\"\(name)\""), name)
        }
        for value in ["top", "side", "back", "shelf", "drawer_front", "drawer_box", "leg", "rail"] {
            XCTAssertTrue(json.contains("\"\(value)\""), value)
        }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(object["required"] as? [String], ["furniture_box_2d", "parts"])
        let parts = try XCTUnwrap((object["properties"] as? [String: Any])?["parts"] as? [String: Any])
        let part = try XCTUnwrap(parts["items"] as? [String: Any])
        XCTAssertEqual(Set(part["required"] as? [String] ?? []), ["type", "damaged", "estimated_width_mm", "estimated_height_mm"],
                       "box_2d, upholstered, curved and note are optional")
    }
}
