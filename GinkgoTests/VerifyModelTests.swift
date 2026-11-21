import GinkgoCore
import XCTest
@testable import Ginkgo

final class VerifyModelTests: XCTestCase {
    /// A proven bench from a typical piece of furniture.
    private func verify() throws -> VerifyModel {
        let box = FittedBox(width: 0.46, depth: 0.40, height: 0.58, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 5000)
        let model = try LivePlan.proof(from: box, scanID: "s").get()
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
    }

    func testOneCheckLeftIsStillPending() throws {
        var v = try verify()
        guard v.checks.count > 1 else { throw XCTSkip("needs two checks") }
        v.record(try XCTUnwrap(v.planned(0)), for: 0)
        XCTAssertEqual(v.status, .pending(remaining: v.checks.count - 1))
    }

    func testAPanelSmallerThanEstimatedWithdrawsThePlan() throws {
        var v = try verify()
        let planned = try XCTUnwrap(v.planned(0))
        v.record(planned - 40, for: 0) // 4 cm shorter than the scan suggested
        guard case .withdrawn(let reasons) = v.status else { return XCTFail("\(v.status)") }
        XCTAssertFalse(reasons.isEmpty, "Say why it no longer fits")
        XCTAssertFalse(v.result.passes)
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

    func testAWholePartsPlanIsWithdrawnWhenAPanelIsNotTheSizeItAssumed() throws {
        // A dresser-sized box gets the reuse-whole plan; a whole panel that turns out bigger no longer
        // matches the plan, so the plan has to be redone rather than cut.
        let box = FittedBox(width: 1.2, depth: 0.5, height: 0.85, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 5000)
        let model = try LivePlan.proof(from: box, scanID: "s").get()
        XCTAssertEqual(model.plan.template, .noCut)
        var v = VerifyModel(plan: model.plan, inventory: model.inventory, result: model.result)
        guard let index = v.checks.indices.first else { throw XCTSkip("no checks for this plan") }
        v.record(try XCTUnwrap(v.planned(index)) + 15, for: index)
        guard case .withdrawn = v.status else { return XCTFail("\(v.status)") }
    }
}
