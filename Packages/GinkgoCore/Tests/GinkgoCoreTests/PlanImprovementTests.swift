import XCTest
@testable import GinkgoCore

final class PlanImprovementTests: XCTestCase {
    private func validation(passes: Bool = true, reuse: Double) -> ValidationResult {
        ValidationResult(passes: passes, placements: [], planID: "p", reusePercent: reuse, sag: [], verify: [],
                         violations: [])
    }

    private func accepted(reuse: Double, passes: Bool = true) throws -> AgentOutcome {
        .accepted(plan: try Fixtures.planBench(), validation: validation(passes: passes, reuse: reuse), trace: [])
    }

    private func fallback(reuse: Double?) throws -> AgentOutcome {
        .fallback(plan: reuse == nil ? nil : try Fixtures.planBench(),
                  validation: reuse.map { validation(reuse: $0) }, trace: [], reason: "r")
    }

    private let device = Route(venue: .device, reason: .numbersOnDevice)
    private let cloud = Route(venue: .cloud, reason: .deviceUnavailable)
    private let rules = Route(venue: .code, reason: .offlineNoDeviceModel)

    // MARK: - When it's offered

    func testOfferedOnlineForAPlanMadeOnThisIPhone() throws {
        XCTAssertTrue(PlanImprovement.isOffered(route: device, outcome: try accepted(reuse: 60), online: true))
    }

    func testOfferedOnlineForTheRuleBasedPlan() throws {
        XCTAssertTrue(PlanImprovement.isOffered(route: rules, outcome: try fallback(reuse: 50), online: true))
    }

    func testOfferedWhenTheCloudRunFellBackToTheRules() throws {
        XCTAssertTrue(PlanImprovement.isOffered(route: cloud, outcome: try fallback(reuse: 50), online: true))
    }

    func testNotOfferedOffline() throws {
        XCTAssertFalse(PlanImprovement.isOffered(route: device, outcome: try accepted(reuse: 60), online: false))
    }

    func testNotOfferedForGeminisOwnAcceptedPlan() throws {
        XCTAssertFalse(PlanImprovement.isOffered(route: cloud, outcome: try accepted(reuse: 60), online: true))
    }

    func testNotOfferedWhilePlanning() {
        XCTAssertFalse(PlanImprovement.isOffered(route: device, outcome: nil, online: true))
    }

    // MARK: - Which plan wins

    func testMoreReuseWins() throws {
        let result = PlanImprovement.compare(original: try accepted(reuse: 60.2), improved: try accepted(reuse: 71.6))
        XCTAssertEqual(result.choice, .improved)
        XCTAssertEqual(result.message, "Improved by Gemini in the cloud: 72% of the wood reused, up from 60%.")
    }

    func testEqualReuseAtTheShownPercentKeepsTheFirstPlan() throws {
        let result = PlanImprovement.compare(original: try accepted(reuse: 60.2), improved: try accepted(reuse: 60.4))
        XCTAssertEqual(result.choice, .original)
        XCTAssertEqual(result.message,
                       "Gemini's plan passes but reuses 60% of the wood, not more than 60%, so this plan stays.")
    }

    func testLessReuseKeepsTheFirstPlan() throws {
        let result = PlanImprovement.compare(original: try accepted(reuse: 70), improved: try accepted(reuse: 55))
        XCTAssertEqual(result.choice, .original)
    }

    func testARejectedCloudPlanNeverReplacesAPassingOne() throws {
        let result = PlanImprovement.compare(original: try accepted(reuse: 40),
                                             improved: try accepted(reuse: 90, passes: false))
        XCTAssertEqual(result.choice, .original)
        XCTAssertEqual(result.message, "Gemini's plan didn't pass the validator, so this plan stays.")
    }

    func testACloudRunThatFellBackToTheRulesIsNotAnImprovement() throws {
        let result = PlanImprovement.compare(original: try accepted(reuse: 40), improved: try fallback(reuse: 90))
        XCTAssertEqual(result.choice, .original)
    }

    func testAPassingCloudPlanReplacesNoPlanAtAll() throws {
        let result = PlanImprovement.compare(original: try fallback(reuse: nil), improved: try accepted(reuse: 35))
        XCTAssertEqual(result.choice, .improved)
        XCTAssertEqual(result.message,
                       "Improved by Gemini in the cloud: it found a plan that passes, 35% of the wood reused.")
    }

    func testAPassingCloudPlanReplacesAFailingFirstPlan() throws {
        let failing = AgentOutcome.accepted(plan: try Fixtures.planBench(), validation: validation(passes: false, reuse: 80),
                                            trace: [])
        XCTAssertEqual(PlanImprovement.compare(original: failing, improved: try accepted(reuse: 30)).choice, .improved)
    }

    // MARK: - Routing

    func testImproveGoesToTheCloudOnlineAndKeepsThePlanOffline() {
        let online = HybridRouter.route(.improvePlan, RouteConditions(deviceModelAvailable: true, online: true))
        XCTAssertEqual(online, Route(venue: .cloud, reason: .improvedInCloud))
        XCTAssertEqual(online.reason.message, "Improved by Gemini in the cloud")
        let offline = HybridRouter.route(.improvePlan, RouteConditions(deviceModelAvailable: true, online: false))
        XCTAssertEqual(offline, Route(venue: .code, reason: .offlineKeepPlan))
    }
}
