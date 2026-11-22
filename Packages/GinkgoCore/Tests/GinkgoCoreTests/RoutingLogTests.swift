@testable import GinkgoCore
import XCTest

final class RoutingLogTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_795_300_000)

    private func entry(_ venue: Venue, _ verdict: ValidatorVerdict, ms: Int, task: AITask = .planFromNumbers,
                       model: String = "m") -> RoutingEntry {
        RoutingEntry(task: task, venue: venue, reason: .numbersOnDevice, model: model, durationMs: ms,
                     verdict: verdict, date: start)
    }

    // MARK: - Recording

    func testANewLogIsEmpty() {
        XCTAssertTrue(RoutingLog().entries.isEmpty)
    }

    func testEntriesKeepTheirOrder() {
        var log = RoutingLog()
        log.record(entry(.device, .passed, ms: 1))
        log.record(entry(.cloud, .failed, ms: 2))
        XCTAssertEqual(log.entries.map(\.durationMs), [1, 2])
    }

    // MARK: - Summary

    func testSummaryCountsEveryRunIncludingFailures() {
        let log = RoutingLog(entries: [entry(.device, .passed, ms: 100), entry(.device, .failed, ms: 300),
                                       entry(.device, .passed, ms: 200), entry(.cloud, .passed, ms: 900)])
        let device = log.summary(for: .device)
        XCTAssertEqual(device.runs, 3)
        XCTAssertEqual(device.passed, 2)
        XCTAssertEqual(device.failed, 1)
        XCTAssertEqual(try XCTUnwrap(device.passRate), 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(device.medianMs, 200)
    }

    func testPassRateLeavesOutRunsWithNothingValidated() {
        let log = RoutingLog(entries: [entry(.cloud, .passed, ms: 1), entry(.cloud, .notRun, ms: 1)])
        XCTAssertEqual(log.summary(for: .cloud).runs, 2)
        XCTAssertEqual(log.summary(for: .cloud).passRate, 1.0)
    }

    func testPassRateIsNilWhenNothingWasValidated() {
        let log = RoutingLog(entries: [entry(.cloud, .notRun, ms: 5)])
        XCTAssertNil(log.summary(for: .cloud).passRate)
    }

    func testAllFailuresGiveAZeroPassRateNotNil() {
        let log = RoutingLog(entries: [entry(.device, .failed, ms: 5), entry(.device, .failed, ms: 6)])
        XCTAssertEqual(log.summary(for: .device).passRate, 0)
    }

    func testAnEmptyVenueHasNoRunsAndNoNumbers() {
        let summary = RoutingLog(entries: [entry(.device, .passed, ms: 5)]).summary(for: .code)
        XCTAssertEqual(summary, VenueSummary(runs: 0, passed: 0, failed: 0, passRate: nil, medianMs: nil))
    }

    func testSummaryCanBeLimitedToOneTask() {
        let log = RoutingLog(entries: [entry(.cloud, .notRun, ms: 50, task: .readPhoto),
                                       entry(.cloud, .passed, ms: 70, task: .planFromNumbers)])
        XCTAssertEqual(log.summary(for: .cloud, task: .planFromNumbers).runs, 1)
        XCTAssertEqual(log.summary(for: .cloud, task: .planFromNumbers).medianMs, 70)
        XCTAssertEqual(log.summary(for: .cloud).runs, 2)
    }

    // MARK: - Median

    func testMedianOfAnOddCountIsTheMiddleValue() {
        XCTAssertEqual(RoutingLog.median([9, 1, 5]), 5)
    }

    func testMedianOfAnEvenCountAveragesTheTwoMiddleValues() {
        XCTAssertEqual(RoutingLog.median([4, 1, 3, 2]), 2.5)
    }

    func testMedianOfOneValueIsThatValue() {
        XCTAssertEqual(RoutingLog.median([7]), 7)
    }

    func testMedianOfNothingIsNil() {
        XCTAssertNil(RoutingLog.median([]))
    }

    // MARK: - JSON Lines

    func testJSONLinesRoundTrip() throws {
        let log = RoutingLog(entries: [
            RoutingEntry(task: .readPhoto, venue: .cloud, reason: .needsPhoto, model: "gemini-3.8-flash",
                         durationMs: 4210, verdict: .notRun, date: start),
            RoutingEntry(task: .planFromNumbers, venue: .device, reason: .numbersOnDevice,
                         model: "apple-foundation-models-system-language-model", durationMs: 2300,
                         verdict: .failed, date: start.addingTimeInterval(5)),
        ])
        XCTAssertEqual(try RoutingLog.parse(jsonLines: try log.jsonLines()), log)
    }

    func testJSONLinesHasOneReadableLinePerEntry() throws {
        let log = RoutingLog(entries: [entry(.device, .passed, ms: 12), entry(.code, .passed, ms: 1)])
        let lines = try log.jsonLines().split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(String(lines[0]),
                       #"{"date":"2026-11-21T22:26:40Z","duration_ms":12,"model":"m","reason":"numbers_on_device","#
                       + #""task":"plan_from_numbers","venue":"device","verdict":"passed"}"#)
    }

    func testAnEmptyLogWritesAnEmptyString() throws {
        XCTAssertEqual(try RoutingLog().jsonLines(), "")
        XCTAssertEqual(try RoutingLog.parse(jsonLines: ""), RoutingLog())
    }

    func testBlankLinesAreSkipped() throws {
        let line = try RoutingLog(entries: [entry(.device, .passed, ms: 3)]).jsonLines()
        XCTAssertEqual(try RoutingLog.parse(jsonLines: "\n\(line)\n  \n").entries.count, 1)
    }

    func testAMalformedLineThrowsInsteadOfBeingDropped() throws {
        let line = try RoutingLog(entries: [entry(.device, .passed, ms: 3)]).jsonLines()
        XCTAssertThrowsError(try RoutingLog.parse(jsonLines: "\(line)\n{\"task\": \"nope\"}"))
    }

    func testAnUnknownVenueThrows() {
        let bad = #"{"date":"2026-11-21T22:26:40Z","duration_ms":1,"model":"m","reason":"numbers_on_device","#
            + #""task":"plan_from_numbers","venue":"mars","verdict":"passed"}"#
        XCTAssertThrowsError(try RoutingLog.parse(jsonLines: bad))
    }
}
