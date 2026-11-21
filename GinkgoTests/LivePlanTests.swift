import GinkgoCore
import XCTest
@testable import Ginkgo

final class LivePlanTests: XCTestCase {
    private func box(width: Float, depth: Float, height: Float) -> FittedBox {
        FittedBox(width: width, depth: depth, height: height, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 5000)
    }

    func testTheMeasuredBoxBecomesATopAndTwoSides() {
        let inventory = LivePlan.inventory(from: box(width: 0.4604, depth: 0.3998, height: 0.58), scanID: "scan-1")
        XCTAssertEqual(inventory.scanID, "scan-1")
        XCTAssertEqual(inventory.parts.map(\.id), ["top", "side_left", "side_right"])
        let top = inventory.parts[0], side = inventory.parts[1]
        XCTAssertEqual(top.widthMm, 460)
        XCTAssertEqual(top.heightMm, 400)
        XCTAssertEqual(side.widthMm, 400, "A side is as deep as the top")
        XCTAssertEqual(side.heightMm, 580 - LivePlan.assumedThicknessMm, "The top sits on the sides")
        XCTAssertTrue(inventory.parts.allSatisfy { !$0.damaged && $0.keepOuts.isEmpty && $0.thicknessMm == 18 })
    }

    func testANightstandBecomesAProvenBench() throws {
        let model = try LivePlan.proof(from: box(width: 0.46, depth: 0.40, height: 0.58), scanID: "scan-1").get()
        XCTAssertEqual(model.verdict, .proven)
        XCTAssertEqual(model.plan.newParts.map(\.name), ["seat", "leg_left", "leg_right"])
        XCTAssertTrue(model.result.passes)
        XCTAssertEqual(model.inventory.scanID, "scan-1")
        // Every cut fits inside the panel it comes from.
        for part in model.plan.newParts {
            let source = try XCTUnwrap(model.inventory.parts.first { $0.id == part.sourcePartID })
            XCTAssertLessThanOrEqual(part.widthMm, source.widthMm)
            XCTAssertLessThanOrEqual(part.heightMm, source.heightMm)
        }
    }

    func testTheBenchCanBeShownInThreeD() throws {
        let model = try LivePlan.proof(from: box(width: 0.46, depth: 0.40, height: 0.58), scanID: "s").get()
        let scene = TransformLayout.scene(plan: model.plan, inventory: model.inventory)
        XCTAssertEqual(scene.pieces.count, 3)
    }

    /// Different furniture, not one prop: each either gets a proven plan whose cuts fit, or a clear "no".
    func testWorksAcrossDifferentFurniture() throws {
        let pieces: [(name: String, box: FittedBox)] = [
            ("side table", box(width: 0.45, depth: 0.45, height: 0.55)),
            ("dresser", box(width: 1.20, depth: 0.50, height: 0.85)),
            ("desk", box(width: 1.40, depth: 0.70, height: 0.75)),
            ("tall cabinet", box(width: 0.80, depth: 0.40, height: 1.80)),
            ("low shelf", box(width: 0.90, depth: 0.30, height: 0.40)),
            ("small cabinet", box(width: 0.60, depth: 0.35, height: 0.70)),
        ]
        for (name, box) in pieces {
            switch LivePlan.proof(from: box, scanID: name) {
            case .success(let model):
                XCTAssertEqual(model.verdict, .proven, name)
                XCTAssertTrue(model.result.violations.isEmpty, name)
                XCTAssertFalse(TransformLayout.scene(plan: model.plan, inventory: model.inventory).pieces.isEmpty, name)
            case .failure(let failure):
                XCTAssertEqual(failure, .noBenchFits, name)
            }
        }
        // Most everyday pieces must actually yield a bench, or the feature is useless.
        let proven = pieces.filter { (try? LivePlan.proof(from: $0.box, scanID: $0.name).get()) != nil }
        XCTAssertGreaterThanOrEqual(proven.count, 5, "Only proven: \(proven.map(\.name))")
    }

    func testSomethingTooSmallForABenchGetsAWholePartsPlan() throws {
        // Too small to cut a bench from: the planner offers its parts reused whole, never a failing plan.
        let tiny = try LivePlan.proof(from: box(width: 0.12, depth: 0.10, height: 0.08), scanID: "s").get()
        XCTAssertEqual(tiny.plan.template, .noCut)
        XCTAssertEqual(tiny.verdict, .proven)
        XCTAssertFalse(LivePlan.Failure.noBenchFits.explanation.isEmpty)
    }
}
