import GinkgoCore
import XCTest
@testable import Ginkgo

final class RecordedRunTests: XCTestCase {
    func testTheRecordingLoadsWithItsWholeTrace() throws {
        let run = try XCTUnwrap(RecordedRun.load())
        XCTAssertEqual(run.outcome, "accepted")
        XCTAssertFalse(run.trace.isEmpty)
        XCTAssertTrue(run.trace.contains { $0.status == .fail }, "It shows Gemini failing a check and repairing")
        XCTAssertEqual(run.trace.map(\.index), Array(run.trace.indices), "Steps are in order")
        XCTAssertTrue(run.detail.hasSuffix(String(format: "accepted in %.1f s", run.seconds)))
    }

    func testTheRecordedPlanStillPassesTodaysValidator() throws {
        let run = try XCTUnwrap(RecordedRun.load())
        let inventory = try XCTUnwrap(ExampleRecordedRunView.sampleInventory())
        let proof = run.proof(inventory: inventory)
        XCTAssertEqual(proof.verdict, .proven, "\(proof.result.violations.map(\.message))")
    }

    func testItIsAlwaysLabeledAsARecording() {
        XCTAssertTrue(RecordedRun.label.contains("Recorded"))
        XCTAssertTrue(RecordedRun.label.contains("sample data"))
    }

    func testNoFilesMeansNoRecording() {
        let empty = Bundle(for: RecordedRunTests.self)
        XCTAssertNil(RecordedRun.load(bundle: empty))
        XCTAssertNil(ExampleRecordedRunView.sampleInventory(bundle: empty))
    }
}
