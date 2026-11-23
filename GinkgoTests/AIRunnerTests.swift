import XCTest
@testable import Ginkgo

/// Records every model call and every wait, and fails on a script.
private actor Script {
    var calls: [String] = []
    var waits: [Duration] = []
    private var outcomes: [Bool] // true = succeed

    init(_ outcomes: [Bool]) { self.outcomes = outcomes }

    func call(_ model: String) throws -> String {
        calls.append(model)
        let ok = outcomes.isEmpty ? false : outcomes.removeFirst()
        if ok { return "answer from \(model)" }
        throw URLError(.badServerResponse)
    }

    func wait(_ d: Duration) { waits.append(d) }
}

final class AIRunnerTests: XCTestCase {
    private func runner(_ script: Script, models: [String] = ["main", "backup"], attempts: Int = 2) -> AIRunner {
        AIRunner(models: models, attemptsPerModel: attempts,
                 backoff: { .milliseconds(100 * $0) },
                 sleep: { await script.wait($0) })
    }

    func testFirstTrySucceedsWithNoWaiting() async throws {
        let s = Script([true])
        let result = try await runner(s).run { try await s.call($0) }
        XCTAssertEqual(result, "answer from main")
        let calls = await s.calls, waits = await s.waits
        XCTAssertEqual(calls, ["main"])
        XCTAssertEqual(waits, [])
    }

    func testRetriesTheSameModelAfterAFailure() async throws {
        let s = Script([false, true])
        let result = try await runner(s).run { try await s.call($0) }
        XCTAssertEqual(result, "answer from main")
        let calls = await s.calls, waits = await s.waits
        XCTAssertEqual(calls, ["main", "main"])
        XCTAssertEqual(waits, [.milliseconds(100)])
    }

    func testFallsBackToTheBackupModelWhenTheMainOneKeepsFailing() async throws {
        let s = Script([false, false, true])
        let result = try await runner(s).run { try await s.call($0) }
        XCTAssertEqual(result, "answer from backup")
        let calls = await s.calls
        XCTAssertEqual(calls, ["main", "main", "backup"])
    }

    func testWaitsGrowAndThereIsNoWaitBeforeSwitchingModels() async throws {
        let s = Script([false, false, false, false])
        _ = try? await runner(s, attempts: 3).run { try await s.call($0) }
        let waits = await s.waits
        // main: fail, wait 100, fail, wait 200, fail; backup: same.
        XCTAssertEqual(waits, [.milliseconds(100), .milliseconds(200), .milliseconds(100), .milliseconds(200)])
    }

    func testWhenEverythingFailsItReportsEveryAttempt() async throws {
        let s = Script([false, false, false, false])
        do {
            _ = try await runner(s).run { try await s.call($0) }
            XCTFail("Expected failure")
        } catch let failure as AIRunner.Failure {
            XCTAssertEqual(failure.attempts.map(\.model), ["main", "main", "backup", "backup"])
        }
    }

    func testCancellationStopsImmediatelyWithoutRetrying() async throws {
        let s = Script([false, true])
        let r = runner(s)
        let task = Task { try await r.run { _ in throw CancellationError() } }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        let calls = await s.calls
        XCTAssertEqual(calls, [], "A cancelled call must not be retried or fall back")
    }

    func testWorstCaseWaitIsComputedFromTimeoutsAndPauses() {
        let s = Script([])
        // 2 models x 3 attempts x 10 s, plus pauses of 100 + 200 ms per model.
        XCTAssertEqual(runner(s, attempts: 3).worstCaseDuration(perAttemptTimeout: .seconds(10)),
                       .seconds(60) + .milliseconds(600))
    }

    func testTheRealSetupNeverMakesAUserWaitAMinute() {
        // If every attempt times out, the app must give up (and fall back) in under a minute.
        let worst = AIRunner.standard.worstCaseDuration(perAttemptTimeout: GeminiClient.requestTimeout)
        XCTAssertLessThan(worst, .seconds(60), "Worst case is \(worst)")
    }

    func testDurationSecondsConversion() {
        XCTAssertEqual(Duration.seconds(12).seconds, 12, accuracy: 1e-9)
        XCTAssertEqual(Duration.milliseconds(1500).seconds, 1.5, accuracy: 1e-9)
    }

    func testStandardRunnerWaitsLongerAfterEachFailure() {
        XCTAssertEqual(AIRunner.standard.backoff(1), .milliseconds(800))
        XCTAssertEqual(AIRunner.standard.backoff(2), .milliseconds(1600))
        XCTAssertEqual(AIRunner.standard.backoff(3), .milliseconds(2400))
    }

    func testStandardRunnerReallySleeps() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        try await AIRunner.standard.sleep(.milliseconds(50))
        XCTAssertGreaterThanOrEqual(clock.now - start, .milliseconds(50))
    }

    func testStandardRunnerSleepStopsWhenCancelled() async {
        let task = Task { try await AIRunner.standard.sleep(.seconds(30)) }
        task.cancel()
        do {
            try await task.value
            XCTFail("A cancelled sleep must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testNoModelsIsReportedNotCrashed() async {
        let script = Script([true])
        do {
            _ = try await runner(script, models: []).run { try await script.call($0) }
            XCTFail("Expected Misconfigured")
        } catch {
            XCTAssertEqual(error as? AIRunner.Misconfigured, AIRunner.Misconfigured())
        }
        let calls = await script.calls
        XCTAssertEqual(calls, [], "Nothing is called")
    }

    func testZeroAttemptsIsReportedNotCrashed() async {
        let script = Script([true])
        do {
            _ = try await runner(script, attempts: 0).run { try await script.call($0) }
            XCTFail("Expected Misconfigured")
        } catch {
            XCTAssertEqual(error as? AIRunner.Misconfigured, AIRunner.Misconfigured())
        }
        let calls = await script.calls
        XCTAssertEqual(calls, [])
    }

    func testStandardRunnerUsesTheCurrentModels() {
        XCTAssertEqual(AIRunner.standard.models, ["gemini-3.8-flash", "gemini-3.5-flash-lite"])
        XCTAssertEqual(AIRunner.standard.attemptsPerModel, 1)
    }
}
