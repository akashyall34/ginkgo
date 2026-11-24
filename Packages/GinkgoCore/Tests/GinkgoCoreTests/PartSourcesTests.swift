@testable import GinkgoCore
import XCTest

/// Guessed numbers are never trusted for strength: guessed wood is rated as particleboard, and a load-bearing
/// panel's estimated thickness must be measured before the plan can be verified.
final class PartSourcesTests: XCTestCase {
    private func part(_ material: Material, materialSource: MaterialSource?, thicknessSource: ThicknessSource?,
                      id: String = "top", type: TypeEnum = .top) -> Part {
        Part(damaged: false, heightMm: 400, id: id, keepOuts: [], material: material, materialSource: materialSource,
             thicknessMm: 19, thicknessSource: thicknessSource, type: type, widthMm: 460)
    }

    // MARK: - Unstated means unsure

    func testTheOldInitializerLeavesBothSourcesUnstated() {
        let old = Part(damaged: false, heightMm: 1, id: "p", keepOuts: [], material: .solidWood, thicknessMm: 19,
                       type: .top, widthMm: 1)
        XCTAssertNil(old.materialSource)
        XCTAssertNil(old.thicknessSource)
        XCTAssertFalse(old.materialIsConfirmed)
        XCTAssertFalse(old.thicknessIsMeasured)
    }

    func testOnlyScanOrTapeCountsAsMeasured() {
        XCTAssertTrue(part(.solidWood, materialSource: nil, thicknessSource: .scanned).thicknessIsMeasured)
        XCTAssertTrue(part(.solidWood, materialSource: nil, thicknessSource: .tape).thicknessIsMeasured)
        XCTAssertFalse(part(.solidWood, materialSource: nil, thicknessSource: .estimated).thicknessIsMeasured)
        XCTAssertFalse(part(.solidWood, materialSource: nil, thicknessSource: nil).thicknessIsMeasured)
    }

    // MARK: - Material for strength

    func testGuessedSolidWoodAndPlywoodAreRatedAsParticleboard() {
        XCTAssertEqual(part(.solidWood, materialSource: .guessed, thicknessSource: nil).ratedForStrength.material, .particleboardMDF)
        XCTAssertEqual(part(.plywood, materialSource: nil, thicknessSource: nil).ratedForStrength.material, .particleboardMDF)
    }

    func testConfirmedMaterialIsRatedAsItIs() {
        XCTAssertEqual(part(.solidWood, materialSource: .confirmed, thicknessSource: nil).ratedForStrength.material, .solidWood)
        XCTAssertEqual(part(.plywood, materialSource: .confirmed, thicknessSource: nil).ratedForStrength.material, .plywood)
    }

    func testParticleboardPlasticAndCardboardAreNeverRaised() {
        for material in [Material.particleboardMDF, .plastic, .cardboard] {
            XCTAssertEqual(part(material, materialSource: .guessed, thicknessSource: nil).ratedForStrength.material, material)
        }
    }

    func testTheSagCheckUsesTheConservativeRating() throws {
        // The same seat on the same top: guessed wood bends more than confirmed solid wood.
        let seat = NewPart(heightMm: 362, name: "seat", positionMm: Vector3(x: 0, y: 0, z: 0), role: .seat,
                           rotationDeg: Vector3(x: 0, y: 0, z: 0), sourcePartID: "top", spanMm: 400, widthMm: 452)
        let guessed = try XCTUnwrap(try Sag.check(seat, source: part(.solidWood, materialSource: nil, thicknessSource: .tape)
            .ratedForStrength))
        let confirmed = try XCTUnwrap(try Sag.check(seat, source: part(.solidWood, materialSource: .confirmed,
                                                                         thicknessSource: .tape).ratedForStrength))
        XCTAssertGreaterThan(guessed.deflectionMm, confirmed.deflectionMm)
    }

    // MARK: - Thickness before cutting

    private func plan(_ parts: [NewPart]) -> Plan {
        Plan(hardware: [], id: "p", newParts: parts, overallMm: nil, scanID: "s", source: .ginkgo, steps: [],
             template: .bench)
    }

    private func newPart(_ name: String, from source: String, role: Role) -> NewPart {
        NewPart(heightMm: 100, name: name, positionMm: Vector3(x: 0, y: 0, z: 0), role: role,
                rotationDeg: Vector3(x: 0, y: 0, z: 0), sourcePartID: source, spanMm: role == .seat || role == .shelf ? 300 : nil,
                widthMm: 100)
    }

    func testAnEstimatedLoadBearingPanelMustBeMeasuredFirst() {
        let parts = ["top": part(.solidWood, materialSource: .confirmed, thicknessSource: .estimated)]
        let checks = Validator.thicknessChecks(plan([newPart("seat", from: "top", role: .seat)]), parts: parts)
        XCTAssertEqual(checks, [VerifyItem(dimension: .thickness, marginMm: 0, sourcePartID: "top")])
    }

    func testAMeasuredPanelNeedsNoThicknessCheck() {
        let parts = ["top": part(.solidWood, materialSource: .confirmed, thicknessSource: .scanned)]
        XCTAssertEqual(Validator.thicknessChecks(plan([newPart("seat", from: "top", role: .seat)]), parts: parts), [])
    }

    func testPartsThatCarryNoLoadNeedNoThicknessCheck() {
        let parts = ["side": part(.solidWood, materialSource: .confirmed, thicknessSource: nil, id: "side", type: .side)]
        XCTAssertEqual(Validator.thicknessChecks(plan([newPart("support", from: "side", role: .support)]), parts: parts), [])
    }

    func testOneCheckPerPanelEvenWithTwoLoadedPartsFromIt() {
        let parts = ["top": part(.solidWood, materialSource: .confirmed, thicknessSource: nil)]
        let checks = Validator.thicknessChecks(plan([newPart("seat", from: "top", role: .seat),
                                                     newPart("shelf", from: "top", role: .shelf)]), parts: parts)
        XCTAssertEqual(checks.count, 1)
    }

    func testThicknessChecksComeFirstAndAreNeverCutOff() throws {
        var inventory = try Fixtures.inventory()
        inventory = Inventory(parts: inventory.parts.map { $0.with(thicknessSource: .some(nil)) }, scanID: inventory.scanID)
        let result = Validator.validate(plan: try Fixtures.planBench(), inventory: inventory, limits: nil)
        XCTAssertEqual(result.verify.first?.dimension, .thickness)
        XCTAssertGreaterThan(result.verify.count, Validator.verifyCount, "Margin checks still follow; thickness isn't capped")
    }

    func testMeasuringTheThicknessInVerifyMarksItMeasured() throws {
        let estimated = part(.solidWood, materialSource: .confirmed, thicknessSource: .estimated)
        XCTAssertFalse(estimated.thicknessIsMeasured)
        let updated = Verifier.resized(estimated, Remeasurement(sourcePartID: "top", dimension: .thickness, valueMm: 17.5))
        XCTAssertEqual(updated.thicknessMm, 17.5)
        XCTAssertEqual(updated.thicknessSource, .tape)
        XCTAssertTrue(updated.thicknessIsMeasured)
    }

    func testAThinnerMeasuredTopCanWithdrawTheBench() throws {
        // 19 mm assumed; really 8 mm: the seat now sags too much, so the plan can't be verified as it was.
        let inventory = try Fixtures.inventory()
        let outcome = Verifier.recheck(plan: try Fixtures.planBench(), inventory: inventory, limits: nil,
                                       measured: Remeasurement(sourcePartID: "top", dimension: .thickness, valueMm: 8))
        if case .verified = outcome { XCTFail("An 8 mm top can't carry the same seat: \(outcome)") }
    }
}

final class RemeasurementSourceTests: XCTestCase {
    func testARemeasureDefaultsToTapeAndCanSayScanned() {
        XCTAssertEqual(Remeasurement(sourcePartID: "top", dimension: .thickness, valueMm: 18).thicknessSource, .tape)
        let part = Part(damaged: false, heightMm: 400, id: "top", keepOuts: [], material: .solidWood, thicknessMm: 18,
                        type: .top, widthMm: 460)
        let scanned = Verifier.resized(part, Remeasurement(sourcePartID: "top", dimension: .thickness, valueMm: 18.3,
                                                           thicknessSource: .scanned))
        XCTAssertEqual(scanned.thicknessSource, .scanned)
        XCTAssertEqual(scanned.thicknessMm, 18.3)
    }

    func testWidthAndHeightRemeasuresLeaveTheThicknessSourceAlone() {
        let part = Part(damaged: false, heightMm: 400, id: "top", keepOuts: [], material: .solidWood, thicknessMm: 18,
                        type: .top, widthMm: 460)
        XCTAssertNil(Verifier.resized(part, Remeasurement(sourcePartID: "top", dimension: .width, valueMm: 455)).thicknessSource)
    }
}
