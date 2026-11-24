@testable import GinkgoCore
import XCTest

/// Solid wood across the grain is rated at 2.7% of its along-grain stiffness (Wood Handbook Table 5-1, basswood
/// ET/EL), and so is solid wood whose grain hasn't been confirmed.
final class WoodGrainTests: XCTestCase {
    private func panel(_ material: Material = .solidWood, grain: Grain?) -> Part {
        Part(damaged: false, grain: grain, heightMm: 400, id: "top", keepOuts: [], material: material,
             materialSource: .confirmed, thicknessMm: 19, thicknessSource: .tape, type: .top, widthMm: 460)
    }

    // MARK: - The factor

    func testASpanAlongTheGrainGetsFullStiffness() {
        XCTAssertEqual(WoodGrain.stiffnessFactor(source: panel(grain: .alongWidth), rotated: false), 1)
        XCTAssertEqual(WoodGrain.stiffnessFactor(source: panel(grain: .alongHeight), rotated: true), 1)
    }

    func testASpanAcrossTheGrainGetsTheAcrossGrainRatio() {
        XCTAssertEqual(WoodGrain.stiffnessFactor(source: panel(grain: .alongWidth), rotated: true), 0.027)
        XCTAssertEqual(WoodGrain.stiffnessFactor(source: panel(grain: .alongHeight), rotated: false), 0.027)
    }

    func testUnknownGrainIsRatedAcross() {
        XCTAssertEqual(WoodGrain.stiffnessFactor(source: panel(grain: nil), rotated: false), WoodGrain.acrossGrainRatio)
    }

    func testAnUnplacedPieceIsJudgedAsPlanned() {
        XCTAssertEqual(WoodGrain.stiffnessFactor(source: panel(grain: .alongWidth), rotated: nil), 1)
    }

    func testOnlySolidWoodHasAGrainRule() {
        for material in [Material.plywood, .particleboardMDF] {
            XCTAssertEqual(WoodGrain.stiffnessFactor(source: panel(material, grain: nil), rotated: false), 1, "\(material)")
        }
    }

    func testTheRatioIsSourced() {
        XCTAssertEqual(WoodGrain.acrossGrainRatio, 0.027)
        XCTAssertTrue(WoodGrain.source.contains("FPL-GTR-282") && WoodGrain.source.contains("Table 5-1"))
    }

    // MARK: - In the validator

    func testTheSampleSeatRunsAlongTheTopsGrainAndPasses() throws {
        let result = Validator.validate(plan: try Fixtures.planBench(), inventory: try Fixtures.inventory(), limits: nil)
        XCTAssertTrue(result.passes, "\(result.violations)")
    }

    func testTheSameSeatAcrossTheGrainSagsTooMuch() throws {
        let inventory = try Fixtures.inventory()
        let across = Inventory(parts: inventory.parts.map { $0.id == "top" ? $0.with(grain: .alongHeight) : $0 },
                               scanID: inventory.scanID)
        let result = Validator.validate(plan: try Fixtures.planBench(), inventory: across, limits: nil)
        XCTAssertFalse(result.passes)
        XCTAssertTrue(result.violations.contains { $0.code == .sags && $0.newPart == "seat" }, "\(result.violations)")
    }

    func testAcrossTheGrainBendsAboutThirtySevenTimesMore() throws {
        let seat = try XCTUnwrap(try Fixtures.planBench().newParts.first { $0.name == "seat" })
        let along = try XCTUnwrap(try Sag.check(seat, source: panel(grain: .alongWidth), stiffnessFactor: 1))
        let across = try XCTUnwrap(try Sag.check(seat, source: panel(grain: .alongWidth), stiffnessFactor: 0.027))
        XCTAssertEqual(across.deflectionMm / along.deflectionMm, 1 / 0.027, accuracy: 0.01)
    }
}
