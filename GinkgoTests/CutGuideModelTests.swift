import GinkgoCore
import simd
import XCTest
@testable import Ginkgo

/// The cut guide's panel stepper and the AR tap flow, on the sample bench.
final class CutGuideModelTests: XCTestCase {
    private func sample() throws -> (ValidationResult, Inventory) {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
        let bench = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory))
        return (bench.validation, inventory)
    }

    private func guide() throws -> CutGuideModel {
        let (result, inventory) = try sample()
        return CutGuideModel(result: result, inventory: inventory)
    }

    // MARK: - Stepping through panels

    func testItStartsOnTheFirstPanelWithCuts() throws {
        let model = try guide()
        XCTAssertFalse(model.isEmpty)
        XCTAssertTrue(model.isFirst)
        XCTAssertTrue(model.title.hasPrefix("Panel 1 of \(model.panels.count): "), model.title)
    }

    func testStepsAreEachPiecesMarksThenTheSawAdvice() throws {
        let model = try guide()
        let current = try XCTUnwrap(model.current)
        XCTAssertEqual(model.steps, current.pieces.map(\.instruction) + [CutGuide.sawAdvice])
    }

    func testNextAndPreviousStayInBounds() throws {
        var model = try guide()
        model.previous()
        XCTAssertEqual(model.index, 0, "No panel before the first")
        for _ in 0..<10 { model.next() }
        XCTAssertEqual(model.index, model.panels.count - 1, "No panel after the last")
        XCTAssertTrue(model.isLast)
        model.previous()
        XCTAssertEqual(model.index, model.panels.count - 2)
    }

    func testTheDrawingShowsOnlyThisPanelsPieces() throws {
        let model = try guide()
        let sheet = try XCTUnwrap(model.sheet)
        XCTAssertEqual(sheet.part.id, model.current?.sourcePartID)
        XCTAssertTrue(sheet.cuts.allSatisfy { $0.sourcePartID == sheet.part.id })
        XCTAssertFalse(sheet.cuts.isEmpty)
    }

    func testAPlanWithNoCutsSaysSo() throws {
        let (_, inventory) = try sample()
        let none = ValidationResult(passes: true, placements: [], planID: "p", reusePercent: 0, sag: [], verify: [],
                                    violations: [])
        let model = CutGuideModel(result: none, inventory: inventory)
        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.title, "No cuts to mark")
        XCTAssertEqual(model.steps, [])
        XCTAssertNil(model.sheet)
    }

    // MARK: - AR tap flow

    private func marking() throws -> CutMarkingModel {
        CutMarkingModel(panel: try XCTUnwrap(try guide().current))
    }

    /// The panel's corners on a floor: bottom edge along +x, left edge along -z, at its scanned size.
    private func corners(of panel: PanelGuide, stretch: Float = 0) -> [SIMD3<Float>] {
        let w = Float(panel.panelWidthMm) / 1000 + stretch, h = Float(panel.panelHeightMm) / 1000
        return [SIMD3(0, 0, 0), SIMD3(w, 0, 0), SIMD3(0, 0, -h)]
    }

    func testItAsksForEachCornerInTurn() throws {
        var model = try marking()
        XCTAssertTrue(model.prompt.contains("bottom-left"))
        model.tap(SIMD3(0, 0, 0))
        XCTAssertTrue(model.prompt.contains("bottom-right"))
        model.tap(SIMD3(0.1, 0, 0))
        XCTAssertTrue(model.prompt.contains("top-left"))
        XCTAssertEqual(model.lines.count, 0, "Nothing to draw before the third tap")
    }

    func testThreeGoodTapsPlaceEveryLine() throws {
        var model = try marking()
        corners(of: model.panel).forEach { model.tap($0) }
        XCTAssertNotNil(model.frame)
        XCTAssertNil(model.problem)
        XCTAssertEqual(model.lines.count, model.panel.pieces.count * 4)
        XCTAssertTrue(model.prompt.hasPrefix("Mark along each green line"))
    }

    func testTapsThatDontMatchTheScanAreExplainedAndStartOver() throws {
        var model = try marking()
        corners(of: model.panel, stretch: 0.02).forEach { model.tap($0) }
        XCTAssertNil(model.frame)
        XCTAssertTrue(model.problem?.contains("bottom edge") == true, model.problem ?? "no problem")
        XCTAssertEqual(model.taps, [], "The taps start over")
        XCTAssertTrue(model.prompt.contains("bottom-left"))
    }

    func testTheNextTapClearsTheOldProblem() throws {
        var model = try marking()
        corners(of: model.panel, stretch: 0.02).forEach { model.tap($0) }
        model.tap(SIMD3(0, 0, 0))
        XCTAssertNil(model.problem)
    }

    func testExtraTapsAfterPlacingAreIgnoredAndResetStartsOver() throws {
        var model = try marking()
        corners(of: model.panel).forEach { model.tap($0) }
        model.tap(SIMD3(5, 5, 5))
        XCTAssertEqual(model.taps.count, 3)
        model.reset()
        XCTAssertNil(model.frame)
        XCTAssertEqual(model.taps, [])
        XCTAssertEqual(model.lines.count, 0)
    }
}
