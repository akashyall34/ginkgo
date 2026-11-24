import GinkgoCore
import XCTest
@testable import Ginkgo

final class VerifyModelTests: XCTestCase {
    /// A proven bench from a typical piece of furniture.
    private func verify() throws -> VerifyModel {
        let box = FittedBox(length: 0.46, width: 0.40, height: 0.58, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 5000)
        let model = try LivePlan.proof(from: box, scanID: "s", material: .solidWood).get()
        XCTAssertEqual(model.plan.template, .bench, "These tests are about a plan with cuts")
        return VerifyModel(plan: model.plan, inventory: model.inventory, result: model.result)
    }

    func testStartsWithTheTightestChecksPending() throws {
        let v = try verify()
        XCTAssertFalse(v.checks.isEmpty)
        XCTAssertLessThanOrEqual(v.checks.count, VerifyModel.maxChecks)
        XCTAssertEqual(v.checks.map(\.marginMm), v.checks.map(\.marginMm).sorted(), "Tightest first")
        XCTAssertEqual(v.status, .pending(remaining: v.checks.count))
        XCTAssertTrue(v.title(of: 0).hasPrefix("The "))
        XCTAssertNotNil(v.planned(0))
    }

    func testMeasuringEveryCheckAsPlannedVerifiesThePlan() throws {
        var v = try verify()
        for index in v.checks.indices { v.record(try XCTUnwrap(v.planned(index)), for: index) }
        XCTAssertEqual(v.status, .verified)
        XCTAssertTrue(v.isBuildable)
    }

    func testOneCheckLeftIsStillPending() throws {
        var v = try verify()
        guard v.checks.count > 1 else { throw XCTSkip("needs two checks") }
        v.record(try XCTUnwrap(v.planned(0)), for: 0)
        XCTAssertEqual(v.status, .pending(remaining: v.checks.count - 1))
    }

    func testAPanelSomewhatSmallerAdjustsThePlanToFit() throws {
        var v = try verify()
        // The first panel size check (the thickness check comes first and is measured as planned).
        let panel = try XCTUnwrap(v.checks.firstIndex { $0.dimension != .thickness })
        let planned = try XCTUnwrap(v.planned(panel))
        let planBefore = v.plan
        for index in v.checks.indices { v.record(try XCTUnwrap(v.planned(index)) - (index == panel ? 40 : 0), for: index) }
        guard case .adjusted(let reason) = v.status else { return XCTFail("\(v.status)") }
        XCTAssertFalse(reason.isEmpty, "Say why it changed")
        XCTAssertTrue(v.result.passes)
        XCTAssertNotEqual(v.plan, planBefore, "The plan was redone for the real size")
        XCTAssertEqual(v.planned(panel), planned - 40)
    }

    func testAPanelFarTooSmallWithdrawsThePlan() throws {
        var v = try verify()
        let panel = try XCTUnwrap(v.checks.firstIndex { $0.dimension != .thickness })
        v.record(120, for: panel) // 12 cm: no bench of any size fits
        guard case .withdrawn(let reasons) = v.status else { return XCTFail("\(v.status)") }
        XCTAssertFalse(reasons.joined().isEmpty)
    }

    func testABiggerPanelStillVerifies() throws {
        var v = try verify()
        for index in v.checks.indices { v.record(try XCTUnwrap(v.planned(index)) + 15, for: index) }
        XCTAssertEqual(v.status, .verified)
    }

    func testTheMeasurementReplacesTheEstimate() throws {
        var v = try verify()
        let planned = try XCTUnwrap(v.planned(0))
        v.record(planned + 3, for: 0)
        XCTAssertEqual(v.planned(0), planned + 3)
        XCTAssertEqual(v.measured[0], planned + 3)
    }

    func testNonsenseMeasurementsAreIgnored() throws {
        var v = try verify()
        let before = v.status
        v.record(0, for: 0)
        v.record(-5, for: 0)
        v.record(.nan, for: 0)
        v.record(500, for: 99)
        XCTAssertEqual(v.status, before)
        XCTAssertTrue(v.measured.isEmpty)
    }

    func testAWholePartsPlanIsAdjustedWhenAPanelIsNotTheSizeItAssumed() throws {
        // A dresser-sized box gets the reuse-whole plan; a whole panel that turns out bigger gets a matching
        // reuse-whole plan for the real size.
        let box = FittedBox(length: 1.2, width: 0.5, height: 0.85, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 5000)
        let model = try LivePlan.proof(from: box, scanID: "s", material: .solidWood).get()
        XCTAssertEqual(model.plan.template, .noCut)
        var v = VerifyModel(plan: model.plan, inventory: model.inventory, result: model.result)
        guard !v.checks.isEmpty else { throw XCTSkip("no checks for this plan") }
        for index in v.checks.indices { v.record(try XCTUnwrap(v.planned(index)) + 15, for: index) }
        guard case .adjusted = v.status else { return XCTFail("\(v.status)") }
        XCTAssertEqual(v.plan.template, .noCut)
    }
}

/// Verify measures the seat panel's thickness first, because the sag check used an estimate.
final class VerifyThicknessTests: XCTestCase {
    private func verify() throws -> VerifyModel {
        let box = FittedBox(length: 0.46, width: 0.40, height: 0.58, baseCenter: .zero, yaw: 0, uncertainty: 0.002,
                            pointCount: 4000)
        let model = try LivePlan.proof(from: box, scanID: "s", material: .solidWood).get()
        return VerifyModel(plan: model.plan, inventory: model.inventory, result: model.result)
    }

    func testTheThicknessComesFirstAndShowsTheEstimate() throws {
        let v = try verify()
        XCTAssertEqual(v.title(of: 0), "The top's thickness")
        XCTAssertEqual(v.planned(0), LivePlan.assumedThicknessMm)
    }

    func testMeasuringTheThicknessReplacesTheEstimateAndCountsAsMeasured() throws {
        var v = try verify()
        v.record(19, for: 0)
        XCTAssertEqual(v.planned(0), 19)
        XCTAssertEqual(v.inventory.parts.first { $0.id == "top" }?.thicknessIsMeasured, true)
    }

    func testAMuchThinnerTopCannotVerifyTheSameBench() throws {
        var v = try verify()
        v.record(6, for: 0)
        if case .verified = v.status { XCTFail("A 6 mm top can't carry the seat the plan assumed: \(v.status)") }
    }
}
