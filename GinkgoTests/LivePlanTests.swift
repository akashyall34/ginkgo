import GinkgoCore
import XCTest
@testable import Ginkgo

final class LivePlanTests: XCTestCase {
    private func box(length: Float, width: Float, height: Float) -> FittedBox {
        FittedBox(length: length, width: width, height: height, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 5000)
    }

    func testTheMeasuredBoxBecomesATopAndTwoSides() {
        let inventory = LivePlan.inventory(from: box(length: 0.4604, width: 0.3998, height: 0.58), scanID: "scan-1")
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
        let model = try LivePlan.proof(from: box(length: 0.46, width: 0.40, height: 0.58), scanID: "scan-1", material: .solidWood).get()
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
        let model = try LivePlan.proof(from: box(length: 0.46, width: 0.40, height: 0.58), scanID: "s", material: .solidWood).get()
        let scene = TransformLayout.scene(plan: model.plan, inventory: model.inventory)
        XCTAssertEqual(scene.pieces.count, 3)
    }

    /// Different furniture, not one prop: each either gets a proven plan whose cuts fit, or a clear "no".
    func testWorksAcrossDifferentFurniture() throws {
        let pieces: [(name: String, box: FittedBox)] = [
            ("side table", box(length: 0.45, width: 0.45, height: 0.55)),
            ("dresser", box(length: 1.20, width: 0.50, height: 0.85)),
            ("desk", box(length: 1.40, width: 0.70, height: 0.75)),
            ("tall cabinet", box(length: 0.80, width: 0.40, height: 1.80)),
            ("low shelf", box(length: 0.90, width: 0.30, height: 0.40)),
            ("small cabinet", box(length: 0.60, width: 0.35, height: 0.70)),
        ]
        for (name, box) in pieces {
            switch LivePlan.proof(from: box, scanID: name, material: .solidWood) {
            case .success(let model):
                XCTAssertEqual(model.verdict, .proven, name)
                XCTAssertTrue(model.result.violations.isEmpty, name)
                XCTAssertFalse(TransformLayout.scene(plan: model.plan, inventory: model.inventory).pieces.isEmpty, name)
            case .failure(let failure):
                XCTAssertEqual(failure, .noBenchFits, name)
            }
        }
        // Most everyday pieces must actually yield a bench, or the feature is useless.
        let proven = pieces.filter { (try? LivePlan.proof(from: $0.box, scanID: $0.name, material: .solidWood).get()) != nil }
        XCTAssertGreaterThanOrEqual(proven.count, 5, "Only proven: \(proven.map(\.name))")
    }

    func testSomethingTooSmallForABenchGetsAWholePartsPlan() throws {
        // Too small to cut a bench from: the planner offers its parts reused whole, never a failing plan.
        let tiny = try LivePlan.proof(from: box(length: 0.12, width: 0.10, height: 0.08), scanID: "s", material: .solidWood).get()
        XCTAssertEqual(tiny.plan.template, .noCut)
        XCTAssertEqual(tiny.verdict, .proven)
        XCTAssertFalse(LivePlan.Failure.noBenchFits.explanation.isEmpty)
    }

    // MARK: - Guessed until confirmed

    func testAScanAloneGivesGuessedMaterialAndEstimatedThickness() {
        let inventory = LivePlan.inventory(from: box(length: 0.46, width: 0.40, height: 0.58), scanID: "s")
        XCTAssertTrue(inventory.parts.allSatisfy { $0.materialSource == .guessed && $0.thicknessSource == .estimated })
    }

    func testConfirmingTheMaterialMarksItConfirmedButNotTheThickness() {
        let inventory = LivePlan.inventory(from: box(length: 0.46, width: 0.40, height: 0.58), scanID: "s", material: .plywood)
        XCTAssertTrue(inventory.parts.allSatisfy { $0.material == .plywood && $0.materialIsConfirmed })
        XCTAssertFalse(inventory.parts.contains { $0.thicknessIsMeasured }, "Only a scan or tape measures thickness")
    }

    func testUnconfirmedWoodNeverGetsABenchItCantProve() throws {
        // Rated as particleboard, a nightstand-sized seat sags too much: the safe answer reuses the panels whole.
        let guessed = try LivePlan.proof(from: box(length: 0.46, width: 0.40, height: 0.58), scanID: "s").get()
        XCTAssertNotEqual(guessed.plan.template, .bench)
        XCTAssertTrue(guessed.result.passes)
    }

    func testABenchPlanAsksForTheSeatPanelsThicknessFirst() throws {
        let model = try LivePlan.proof(from: box(length: 0.46, width: 0.40, height: 0.58), scanID: "s", material: .solidWood).get()
        XCTAssertEqual(model.result.verify.first?.dimension, .thickness)
        XCTAssertEqual(model.checksBeforeCutting.first, "Measure the top's thickness: the sag check used 18 mm, an estimate.")
    }
}
