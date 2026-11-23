import GinkgoCore
import XCTest
@testable import Ginkgo

/// Every route the hybrid planner can take, with a fake on-device model and a fake cloud.
final class HybridPlannerTests: XCTestCase {
    private struct FakeDevice: DevicePlanning {
        var isAvailable = true
        var result: DevicePlanResult
        func plan(inventory: Inventory, request: String, onStep: @escaping @Sendable (AgentStep) -> Void) async -> DevicePlanResult {
            result.trace.forEach(onStep)
            return result
        }
    }

    private final class CloudCalls: @unchecked Sendable { var count = 0 }

    private func inventory() throws -> Inventory {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        return try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
    }

    private func bench() throws -> AcceptedPlan {
        let made = try XCTUnwrap(RuleBasedPlanner.bench(inventory: try inventory()))
        return AcceptedPlan(plan: made.plan, validation: made.validation)
    }

    private func step(_ index: Int, _ status: Status, _ tool: Tool = .checkFit) -> AgentStep {
        AgentStep(index: index, reason: "", status: status, summary: "seat from top: fits, 12 mm to spare", tool: tool)
    }

    private func planner(_ device: FakeDevice, calls: CloudCalls = CloudCalls(),
                         cloud: AgentOutcome? = nil) throws -> HybridPlanner {
        let accepted = try bench()
        let cloudOutcome = cloud ?? .accepted(plan: accepted.plan, validation: accepted.validation,
                                              trace: [step(0, .accepted, .submitPlan)])
        return HybridPlanner(device: device, cloud: { _, _, _ in calls.count += 1; return cloudOutcome },
                             cloudModelName: "gemini-test", now: { ContinuousClock.now }, date: { Date(timeIntervalSince1970: 0) })
    }

    // MARK: - On the device

    func testAnAcceptedOnDevicePlanNeverCallsTheCloud() async throws {
        let calls = CloudCalls()
        let device = FakeDevice(result: DevicePlanResult(accepted: try bench(), trace: [step(0, .pass), step(1, .accepted, .submitPlan)],
                                                         rejections: 0, model: "apple-on-device"))
        let result = try await planner(device, calls: calls)
            .run(inventory: try inventory(), request: "Make a bench.", online: true) { _ in }
        XCTAssertEqual(result.route, Route(venue: .device, reason: .numbersOnDevice))
        XCTAssertEqual(calls.count, 0)
        guard case .accepted(_, _, let trace) = result.outcome else { return XCTFail("Expected an accepted plan") }
        XCTAssertEqual(trace.count, 2)
        XCTAssertEqual(result.entries.map(\.venue), [.device])
        XCTAssertEqual(result.entries.first?.verdict, .passed)
        XCTAssertEqual(result.entries.first?.model, "apple-on-device")
    }

    func testItWorksOfflineOnTheDevice() async throws {
        let device = FakeDevice(result: DevicePlanResult(accepted: try bench(), trace: [], rejections: 1, model: "apple-on-device"))
        let result = try await planner(device).run(inventory: try inventory(), request: "", online: false) { _ in }
        XCTAssertEqual(result.route.venue, .device)
        XCTAssertNotNil(result.outcome.plan)
    }

    func testStepsReachTheScreenAsTheyHappen() async throws {
        let seen = CloudCalls()
        let device = FakeDevice(result: DevicePlanResult(accepted: try bench(), trace: [step(0, .pass), step(1, .accepted, .submitPlan)],
                                                         rejections: 0, model: "m"))
        _ = try await planner(device).run(inventory: try inventory(), request: "", online: true) { _ in seen.count += 1 }
        XCTAssertEqual(seen.count, 2)
    }

    // MARK: - On to the cloud

    func testAFailedDeviceRunMovesToTheCloudAndKeepsTheDeviceSteps() async throws {
        let calls = CloudCalls()
        let device = FakeDevice(result: DevicePlanResult(accepted: nil, trace: [step(0, .fail), step(1, .fail), step(2, .fail)],
                                                         rejections: 3, model: "apple-on-device"))
        let result = try await planner(device, calls: calls).run(inventory: try inventory(), request: "", online: true) { _ in }
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(result.route, Route(venue: .cloud, reason: .deviceFailedValidator))
        XCTAssertEqual(result.outcome.trace.map(\.index), [0, 1, 2, 3], "Device steps first, then the cloud's, numbered on")
        XCTAssertEqual(result.entries.map(\.venue), [.device, .cloud])
        XCTAssertEqual(result.entries.map(\.verdict), [.failed, .passed])
        XCTAssertEqual(result.entries.last?.model, "gemini-test")
    }

    func testADeviceRunThatEndsWithoutAPlanGoesToTheCloudAndSaysWhyHonestly() async throws {
        let device = FakeDevice(result: DevicePlanResult(accepted: nil, trace: [], rejections: 0, model: "m",
                                                         error: "assetsUnavailable"))
        let result = try await planner(device).run(inventory: try inventory(), request: "", online: true) { _ in }
        XCTAssertEqual(result.route, Route(venue: .cloud, reason: .deviceDidNotFinish),
                       "Not 'failed the validator 3 times': it never got that far")
    }

    func testNoDeviceModelGoesStraightToTheCloud() async throws {
        let calls = CloudCalls()
        let device = FakeDevice(isAvailable: false, result: DevicePlanResult(accepted: nil, trace: [], rejections: 0, model: "m"))
        let result = try await planner(device, calls: calls).run(inventory: try inventory(), request: "", online: true) { _ in }
        XCTAssertEqual(result.route, Route(venue: .cloud, reason: .deviceUnavailable))
        XCTAssertEqual(result.entries.map(\.venue), [.cloud])
        XCTAssertEqual(calls.count, 1)
    }

    func testWhenTheCloudFallsBackTheLogSaysRuleBased() async throws {
        let device = FakeDevice(isAvailable: false, result: DevicePlanResult(accepted: nil, trace: [], rejections: 0, model: "m"))
        let safe = try bench()
        let fallback = AgentOutcome.fallback(plan: safe.plan, validation: safe.validation, trace: [], reason: "Couldn't reach Gemini")
        let result = try await planner(device, cloud: fallback).run(inventory: try inventory(), request: "", online: true) { _ in }
        XCTAssertEqual(result.entries.last?.model, "rule-based")
        XCTAssertEqual(result.entries.last?.verdict, .passed)
    }

    // MARK: - Offline, no usable model

    func testOfflineWithNoDeviceModelUsesTheRules() async throws {
        let calls = CloudCalls()
        let device = FakeDevice(isAvailable: false, result: DevicePlanResult(accepted: nil, trace: [], rejections: 0, model: "m"))
        let result = try await planner(device, calls: calls).run(inventory: try inventory(), request: "", online: false) { _ in }
        XCTAssertEqual(calls.count, 0, "No network: the cloud is never tried")
        XCTAssertEqual(result.route, Route(venue: .code, reason: .offlineNoDeviceModel))
        XCTAssertNotNil(result.outcome.plan, "The rule-based plan")
        XCTAssertEqual(result.outcome.trace.last?.tool, .fallback)
        XCTAssertEqual(result.entries.last?.model, "rule-based")
    }

    func testOfflineAfterTheDeviceFailedUsesTheRulesAndKeepsTheSteps() async throws {
        let device = FakeDevice(result: DevicePlanResult(accepted: nil, trace: [step(0, .fail)], rejections: 3, model: "m"))
        let result = try await planner(device).run(inventory: try inventory(), request: "", online: false) { _ in }
        XCTAssertEqual(result.route, Route(venue: .code, reason: .offlineDeviceFailed))
        XCTAssertEqual(result.outcome.trace.first?.status, .fail)
        XCTAssertEqual(result.entries.map(\.venue), [.device, .code])
    }

    func testNoSafePlanIsReportedNotInvented() {
        let empty = Inventory(parts: [], scanID: "s")
        let outcome = HybridPlanner.ruleBased(inventory: empty, trace: [], reason: "offline")
        XCTAssertNil(outcome.plan)
        XCTAssertEqual(outcome.trace.last?.status, .error)
    }

    // MARK: - Helpers

    func testPrefixingWithNothingChangesNothing() throws {
        let safe = try bench()
        let outcome = AgentOutcome.accepted(plan: safe.plan, validation: safe.validation, trace: [step(0, .pass)])
        XCTAssertEqual(HybridPlanner.prefixed(outcome, with: []), outcome)
    }

    func testTheLogRecordsHowLongEachStageTook() async throws {
        let ticks = CloudCalls()
        let base = ContinuousClock.now
        let device = FakeDevice(result: DevicePlanResult(accepted: try bench(), trace: [], rejections: 0, model: "m"))
        var timed = try planner(device)
        timed.now = { ticks.count += 1; return base.advanced(by: .milliseconds(1500 * ticks.count)) }
        let result = await timed.run(inventory: try inventory(), request: "", online: true) { _ in }
        XCTAssertEqual(result.entries.first?.durationMs, 1500)
    }
}
