@testable import GinkgoCore
import XCTest

final class RuleBasedPlannerTests: XCTestCase {
    private func part(_ id: String, _ type: TypeEnum, _ size: [Double], _ material: Material = .solidWood,
                      damaged: Bool = false) -> Part {
        // Confirmed material and measured thickness: these tests are about planning, not about guesses.
        Part(damaged: damaged, grain: .alongWidth, heightMm: size[1], id: id, keepOuts: [], material: material,
             materialSource: .confirmed, thicknessMm: 19, thicknessSource: .tape, type: type, widthMm: size[0])
    }

    private func inventory(_ parts: [Part]) -> Inventory {
        Inventory(parts: parts, scanID: "scan-test")
    }

    private func named(_ plan: Plan, _ name: String) throws -> NewPart {
        try XCTUnwrap(plan.newParts.first { $0.name == name })
    }

    // MARK: - The example nightstand

    func testExampleGivesTheGuidesBench() throws {
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: try Fixtures.inventory()))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .bench)
        XCTAssertEqual(plan.id, "plan-fallback")
        XCTAssertEqual(plan.scanID, "scan-nightstand-1")

        let seat = try named(plan, "seat")
        XCTAssertEqual(seat.sourcePartID, "top")
        XCTAssertEqual([seat.widthMm, seat.heightMm], [452, 362], "stepped down from 392 around the screw holes")
        XCTAssertEqual(seat.spanMm, 414)
        for (name, source) in [("leg_left", "side_left"), ("leg_right", "side_right")] {
            let leg = try named(plan, name)
            XCTAssertEqual(leg.sourcePartID, source)
            XCTAssertEqual([leg.widthMm, leg.heightMm], [362, 420])
            XCTAssertEqual(leg.role, .support)
        }
        let sag = try XCTUnwrap(validation.sag.first)
        XCTAssertEqual(sag.deflectionMm, 0.487, accuracy: 0.001)
        XCTAssertEqual(sag.limitMm, 0.69, accuracy: 0.001)
        XCTAssertEqual(plan.overallMm, Vector3(x: 452, y: 439, z: 362))
    }

    func testExampleBenchHasShortStepsAndScrews() throws {
        let (plan, _) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: try Fixtures.inventory()))
        XCTAssertTrue((3...6).contains(plan.steps.count))
        XCTAssertEqual(plan.steps.first, "Cut the seat, 452 × 362 mm, from the top, clear of any screw holes.")
        XCTAssertEqual(plan.hardware, [HardwareItem(item: "wood screw, 40 mm", quantity: 8)])
        XCTAssertFalse(plan.newParts.contains { $0.sourcePartID == "drawer_front" }, "the damaged part is never used")
    }

    // MARK: - Other inventories

    func testAllParticleboardGivesANoCutPlanThatPasses() throws {
        let parts = [part("top", .top, [460, 400], .particleboardMDF), part("side", .side, [380, 560], .particleboardMDF),
                     part("broken", .back, [300, 300], .particleboardMDF, damaged: true)]
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory(parts)))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .noCut)
        XCTAssertEqual(plan.newParts.map(\.name), ["top", "side"])
        XCTAssertEqual(plan.newParts.map(\.widthMm), [460, 380], "reused whole")
        XCTAssertEqual(plan.hardware, [HardwareItem(item: "wood screw, 40 mm", quantity: 2)])
    }

    func testEveryPartDamagedGivesNil() {
        let parts = [part("top", .top, [460, 400], damaged: true), part("side", .side, [380, 560], damaged: true)]
        XCTAssertNil(RuleBasedPlanner.bench(inventory: inventory(parts)))
        XCTAssertNil(RuleBasedPlanner.bench(inventory: inventory([])))
    }

    func testSinglePartGivesAPassingNoCutPlan() throws {
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory([part("top", .top, [460, 400])])))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .noCut)
        XCTAssertEqual(plan.hardware, [], "one part needs no screws")
    }

    func testParticleboardTopIsSkippedAsASeat() throws {
        let example = try Fixtures.inventory()
        let parts = example.parts.map { part -> Part in
            guard part.id == "top" else { return part }
            return Part(damaged: false, heightMm: 400, id: "top", keepOuts: part.keepOuts, material: .particleboardMDF,
                        thicknessMm: 19, type: .top, widthMm: 460)
        }
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory(parts)))
        XCTAssertTrue(validation.passes, "the only cuttable parts are the two sides, so one becomes the seat and there are no legs")
        XCTAssertEqual(plan.template, .noCut)
    }

    func testWithoutTypedPartsTheLargestPartsAreUsed() throws {
        // No part is a top or a side: the largest part is the seat, the next two (ties by ID) are the legs.
        let parts = [part("c", .back, [380, 400]), part("a", .back, [420, 380]), part("b", .shelf, [380, 400])]
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory(parts)))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .bench)
        let seat = try named(plan, "seat")
        XCTAssertEqual(seat.sourcePartID, "a")
        XCTAssertEqual([seat.widthMm, seat.heightMm, seat.spanMm], [412, 372, 374])
        XCTAssertEqual(try named(plan, "leg_left").sourcePartID, "b")
        XCTAssertEqual(try named(plan, "leg_right").sourcePartID, "c")
        XCTAssertEqual(try named(plan, "leg_left").heightMm, 392)
    }

    func testShortPartsGiveShorterMatchingLegs() throws {
        let parts = [part("top", .top, [460, 400]), part("s1", .side, [380, 360]), part("s2", .side, [380, 340])]
        let (plan, _) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory(parts)))
        // Widths: min(362, 360 - 8) and min(362, 340 - 8); heights: min(420, 380 - 8). Both legs take the smaller.
        for name in ["leg_left", "leg_right"] {
            let leg = try named(plan, name)
            XCTAssertEqual([leg.widthMm, leg.heightMm], [332, 372], name)
        }
    }

    func testTooSmallForABenchFallsBackToNoCut() throws {
        let parts = [part("top", .top, [190, 190]), part("s1", .side, [380, 560]), part("s2", .side, [380, 560])]
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory(parts)))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .noCut, "a 182 mm seat is below the 200 mm minimum")
    }

    func testLegsTooShortFallBackToNoCut() throws {
        let parts = [part("top", .top, [460, 400]), part("s1", .side, [250, 290]), part("s2", .side, [250, 290])]
        XCTAssertEqual(try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory(parts))).plan.template, .noCut)
    }

    func testSizeLimitsAreRespected() throws {
        let example = try Fixtures.inventory()
        let roomy = SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: 452)
        XCTAssertEqual(try XCTUnwrap(RuleBasedPlanner.bench(inventory: example, limits: roomy)).plan.template, .bench)
        let narrow = SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: 420)
        XCTAssertNil(RuleBasedPlanner.bench(inventory: example, limits: narrow), "an honest no beats a plan that breaks the limit")
    }

    // MARK: - Property: never a failing plan

    func testTwentyInventoriesGiveNilOrAPassingPlan() {
        let materials: [Material] = [.solidWood, .plywood, .particleboardMDF]
        var benches = 0
        for index in 0..<20 {
            let step = Double(index)
            let parts = [
                part("top", .top, [250 + step * 23, 200 + step * 17], materials[index % 3]),
                part("left", .side, [150 + step * 19, 250 + step * 21], materials[(index + 1) % 3], damaged: index % 7 == 3),
                part("right", .side, [160 + step * 13, 240 + step * 29], .solidWood),
                part("back", .back, [300 + step * 11, 300 + step * 7], materials[(index + 2) % 3], damaged: index % 5 == 4),
            ]
            guard let result = RuleBasedPlanner.bench(inventory: inventory(parts)) else { continue }
            XCTAssertTrue(result.validation.passes, "inventory \(index)")
            XCTAssertEqual(result.validation, Validator.validate(plan: result.plan, inventory: inventory(parts), limits: nil))
            if result.plan.template == .bench { benches += 1 }
        }
        XCTAssertGreaterThan(benches, 0, "the loop covers real benches, not only no-cut plans")
    }
}
