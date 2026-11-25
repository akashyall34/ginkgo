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

    // MARK: - Reading the photo once the network is back

    func testRereadIsOfferedOnlyForAnOfflineEstimateWithAPhotoWhileOnline() {
        let estimate = PartsStep.estimate(box, scanID: "s")
        XCTAssertTrue(PartsStep.canReread(estimate, hasPhoto: true, online: true))
        XCTAssertFalse(PartsStep.canReread(estimate, hasPhoto: true, online: false))
        XCTAssertFalse(PartsStep.canReread(estimate, hasPhoto: false, online: true))
        let read = PartsResult(inventory: estimate.inventory, flags: [], fromGemini: true)
        XCTAssertFalse(PartsStep.canReread(read, hasPhoto: true, online: true))
    }

    func testGeminisRereadReplacesTheEstimate() async {
        let estimate = PartsStep.estimate(box, scanID: "s")
        let attempt = await PartsStep.read(photo: photo, box: box, scanID: "s") { _, _ in self.answer }
        let result = PartsStep.reread(edited: estimate.inventory, flags: estimate.flags, attempt: attempt)
        XCTAssertTrue(result.fromGemini)
        XCTAssertEqual(result.inventory.parts.filter(\.damaged).count, 1, "Gemini's reading, not the estimate")
    }

    func testAFailedRereadKeepsThePersonsChangesAndSaysSoOnce() async {
        struct Offline: Error {}
        let estimate = PartsStep.estimate(box, scanID: "s")
        let edited = PartsStep.setting(.plywood, of: "top", in: estimate.inventory)
        let attempt = await PartsStep.read(photo: photo, box: box, scanID: "s") { _, _ in throw Offline() }
        let once = PartsStep.reread(edited: edited, flags: estimate.flags, attempt: attempt)
        XCTAssertEqual(once.inventory, edited)
        XCTAssertFalse(once.fromGemini)
        XCTAssertEqual(once.flags.map(\.message), [PartsStep.offlineMessage, PartsStep.rereadFailed])
        let twice = PartsStep.reread(edited: edited, flags: once.flags, attempt: attempt)
        XCTAssertEqual(twice.flags.count, 2)
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

/// What the Parts screen says about guessed and estimated numbers, and how confirming works.
final class PartSourcesWordingTests: XCTestCase {
    private func part(_ material: GinkgoCore.Material, _ materialSource: MaterialSource?,
                      thickness: ThicknessSource?) -> GinkgoCore.Part {
        GinkgoCore.Part(damaged: false, heightMm: 350, id: "top", keepOuts: [], material: material, materialSource: materialSource,
             thicknessMm: 18, thicknessSource: thickness, type: .top, widthMm: 600)
    }

    func testAnEstimatedThicknessSaysSo() {
        XCTAssertEqual(PartsStep.sizeLine(part(.solidWood, nil, thickness: .estimated)), "60.0 × 35.0 cm, 18 mm thick (estimated)")
        XCTAssertEqual(PartsStep.sizeLine(part(.solidWood, nil, thickness: nil)), "60.0 × 35.0 cm, 18 mm thick (estimated)")
    }

    func testAMeasuredThicknessDoesNot() {
        XCTAssertEqual(PartsStep.sizeLine(part(.solidWood, nil, thickness: .scanned)), "60.0 × 35.0 cm, 18 mm thick")
    }

    func testGuessedWoodOffersAOneTapConfirm() {
        XCTAssertEqual(PartsStep.materialNote(part(.solidWood, .guessed, thickness: nil)),
                       "Guessed. Rated as particleboard until you confirm. Tap if it's solid wood.")
        XCTAssertEqual(PartsStep.materialNote(part(.plywood, nil, thickness: nil)),
                       "Guessed. Rated as particleboard until you confirm. Tap if it's plywood.")
    }

    func testNoNoteOnceConfirmedOrWhenAGuessCantBeWeaker() {
        XCTAssertNil(PartsStep.materialNote(part(.solidWood, .confirmed, thickness: nil)))
        XCTAssertNil(PartsStep.materialNote(part(.particleboardMDF, .guessed, thickness: nil)))
        XCTAssertNil(PartsStep.materialNote(part(.plastic, nil, thickness: nil)))
    }

    func testPickingOrConfirmingAMaterialMarksItConfirmed() {
        let inventory = GinkgoCore.Inventory(parts: [part(.solidWood, .guessed, thickness: nil)], scanID: "s")
        let picked = PartsStep.setting(.plywood, of: "top", in: inventory).parts[0]
        XCTAssertEqual(picked.material, .plywood)
        XCTAssertTrue(picked.materialIsConfirmed)
        let kept = PartsStep.setting(.solidWood, of: "top", in: inventory).parts[0]
        XCTAssertTrue(kept.materialIsConfirmed, "Tapping the confirm line keeps the material and confirms it")
    }
}

final class GrainWordingTests: XCTestCase {
    private func part(_ material: GinkgoCore.Material, grain: Grain?) -> GinkgoCore.Part {
        GinkgoCore.Part(damaged: false, grain: grain, heightMm: 350, id: "top", keepOuts: [], material: material,
                        materialSource: .confirmed, thicknessMm: 18, thicknessSource: .tape, type: .top, widthMm: 600)
    }

    func testUncheckedSolidWoodSaysItsRatedAcrossTheGrain() {
        XCTAssertTrue(PartsStep.grainNote(part(.solidWood, grain: nil))?.hasPrefix("Not checked: rated as across the grain") == true)
    }

    func testNoNoteOnceCheckedOrForOtherMaterials() {
        XCTAssertNil(PartsStep.grainNote(part(.solidWood, grain: .alongWidth)))
        XCTAssertNil(PartsStep.grainNote(part(.plywood, grain: nil)))
    }

    func testPickingTheGrainSetsIt() {
        let inventory = GinkgoCore.Inventory(parts: [part(.solidWood, grain: nil)], scanID: "s")
        XCTAssertEqual(PartsStep.setting(grain: .alongHeight, of: "top", in: inventory).parts[0].grain, .alongHeight)
    }

    func testAScanConfirmedForGrainRunsTheTopSideToSideAndTheSidesUp() {
        let box = FittedBox(length: 0.46, width: 0.40, height: 0.58, baseCenter: .zero, yaw: 0, uncertainty: 0.002,
                            pointCount: 4000)
        let parts = LivePlan.inventory(from: box, scanID: "s", material: .solidWood, grainConfirmed: true).parts
        XCTAssertEqual(parts.first { $0.type == .top }?.grain, .alongWidth)
        XCTAssertTrue(parts.filter { $0.type == .side }.allSatisfy { $0.grain == .alongHeight })
        XCTAssertTrue(LivePlan.inventory(from: box, scanID: "s").parts.allSatisfy { $0.grain == nil })
    }
}
