import GinkgoCore
import XCTest
@testable import Ginkgo

final class ImpactTests: XCTestCase {
    private func part(_ id: String, w: Double, h: Double) -> Part {
        Part(damaged: false, heightMm: h, id: id, keepOuts: [], material: .solidWood, thicknessMm: 18, type: .top, widthMm: w)
    }

    private func newPart(_ source: String, w: Double, h: Double) -> NewPart {
        NewPart(heightMm: h, name: "piece", positionMm: Vector3(x: 0, y: 0, z: 0), role: .other,
                rotationDeg: Vector3(x: 0, y: 0, z: 0), sourcePartID: source, spanMm: nil, widthMm: w)
    }

    private func plan(_ parts: [NewPart], template: Template = .bench) -> Plan {
        Plan(hardware: [], id: "p", newParts: parts, overallMm: nil, scanID: "s", source: .ginkgo, steps: [], template: template)
    }

    private func result(reuse: Double) throws -> ValidationResult {
        let json = #"{"plan_id": "p", "passes": true, "violations": [], "placements": [], "sag": [], "#
            + #""reuse_percent": \#(reuse), "verify": []}"#
        return try JSONDecoder().decode(ValidationResult.self, from: Data(json.utf8))
    }

    func testAreaIsTheSumOfTheReusedPieces() throws {
        let inventory = Inventory(parts: [part("top", w: 1500, h: 1000), part("side", w: 500, h: 800)], scanID: "s")
        let impact = Impact.of(plan: plan([newPart("top", w: 1000, h: 1000), newPart("side", w: 400, h: 500)]),
                               inventory: inventory, result: try result(reuse: 66.7))
        XCTAssertEqual(impact.reusedAreaM2, 1.2, accuracy: 1e-12)
        XCTAssertEqual(impact.reusePercent, 66.7)
        XCTAssertEqual(impact.cuts, 2)
        XCTAssertEqual(impact.summary, "67% reused · 1.20 m² of material")
        XCTAssertEqual(impact.difficulty, "2 cuts")
    }

    func testAWholePartsPlanHasNoCuts() throws {
        let inventory = Inventory(parts: [part("top", w: 500, h: 400)], scanID: "s")
        let impact = Impact.of(plan: plan([newPart("top", w: 500, h: 400)], template: .noCut),
                               inventory: inventory, result: try result(reuse: 100))
        XCTAssertEqual(impact.cuts, 0)
        XCTAssertEqual(impact.difficulty, "No cuts: reuse the parts whole")
        XCTAssertEqual(Impact(reusePercent: 10, reusedAreaM2: 0.1, cuts: 1).difficulty, "1 cut")
    }

    func testAPieceFromAnUnknownPanelCountsForNothing() throws {
        let impact = Impact.of(plan: plan([newPart("ghost", w: 500, h: 500)]),
                               inventory: Inventory(parts: [], scanID: "s"), result: try result(reuse: 0))
        XCTAssertEqual(impact.reusedAreaM2, 0)
        XCTAssertEqual(impact.cuts, 0)
    }

    func testTheIdeasAskForTheRightBuild() {
        XCTAssertEqual(Idea.bench.request, Prompts.defaultRequest)
        XCTAssertEqual(Idea.bookshelf.request, "Make a bookshelf.")
        XCTAssertEqual(Idea.allCases.map(\.title), ["Bench", "Bookshelf"])
    }
}
