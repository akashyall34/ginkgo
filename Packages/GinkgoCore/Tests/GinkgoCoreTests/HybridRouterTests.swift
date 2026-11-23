@testable import GinkgoCore
import XCTest

final class HybridRouterTests: XCTestCase {
    private func route(_ task: AITask, device: Bool, online: Bool, rejections: Int = 0) -> Route {
        HybridRouter.route(task, RouteConditions(deviceModelAvailable: device, online: online,
                                                 deviceRejections: rejections))
    }

    // MARK: - Planning from numbers: the phone first

    func testPlanningRunsOnDeviceWhenTheModelIsAvailable() {
        XCTAssertEqual(route(.planFromNumbers, device: true, online: true), Route(venue: .device, reason: .numbersOnDevice))
    }

    func testPlanningStaysOnDeviceOffline() {
        XCTAssertEqual(route(.planFromNumbers, device: true, online: false), Route(venue: .device, reason: .numbersOnDevice))
    }

    func testPlanningStaysOnDeviceJustBelowTheRejectionLimit() {
        let route = route(.planFromNumbers, device: true, online: true, rejections: HybridRouter.deviceAttempts - 1)
        XCTAssertEqual(route.venue, .device)
    }

    func testPlanningMovesToTheCloudAtExactlyTheRejectionLimit() {
        XCTAssertEqual(route(.planFromNumbers, device: true, online: true, rejections: HybridRouter.deviceAttempts),
                       Route(venue: .cloud, reason: .deviceFailedValidator))
    }

    func testPlanningStaysInTheCloudPastTheRejectionLimit() {
        XCTAssertEqual(route(.planFromNumbers, device: true, online: true, rejections: 10).venue, .cloud)
    }

    func testTheRejectionLimitIsThree() {
        XCTAssertEqual(HybridRouter.deviceAttempts, 3)
    }

    func testPlanningGoesToTheCloudWhenTheDeviceModelIsMissing() {
        XCTAssertEqual(route(.planFromNumbers, device: false, online: true), Route(venue: .cloud, reason: .deviceUnavailable))
    }

    func testPlanningFallsBackToCodeWithNoModelAndNoNetwork() {
        XCTAssertEqual(route(.planFromNumbers, device: false, online: false),
                       Route(venue: .code, reason: .offlineNoDeviceModel))
    }

    func testPlanningFallsBackToCodeWhenTheDeviceFailedAndThereIsNoNetwork() {
        XCTAssertEqual(route(.planFromNumbers, device: true, online: false, rejections: 3),
                       Route(venue: .code, reason: .offlineDeviceFailed))
    }

    func testADeviceRunThatStoppedEarlyGoesToTheCloudWithAnHonestReason() {
        let route = HybridRouter.route(.planFromNumbers, RouteConditions(deviceModelAvailable: true, online: true,
                                                                         deviceRejections: 1, deviceFinishedWithoutPlan: true))
        XCTAssertEqual(route, Route(venue: .cloud, reason: .deviceDidNotFinish))
    }

    func testThreeRejectionsStillSayFailedTheValidatorEvenIfTheRunEnded() {
        let route = HybridRouter.route(.planFromNumbers, RouteConditions(deviceModelAvailable: true, online: true,
                                                                         deviceRejections: 3, deviceFinishedWithoutPlan: true))
        XCTAssertEqual(route.reason, .deviceFailedValidator)
    }

    func testADeviceRunThatStoppedEarlyOfflineUsesTheRules() {
        let route = HybridRouter.route(.planFromNumbers, RouteConditions(deviceModelAvailable: true, online: false,
                                                                         deviceFinishedWithoutPlan: true))
        XCTAssertEqual(route, Route(venue: .code, reason: .offlineDeviceFailed))
    }

    // MARK: - Reading the photo: the cloud, or the LiDAR template offline

    func testPhotoGoesToTheCloudEvenWhenTheDeviceModelIsAvailable() {
        XCTAssertEqual(route(.readPhoto, device: true, online: true), Route(venue: .cloud, reason: .needsPhoto))
    }

    func testPhotoGoesToTheCloudWithNoDeviceModel() {
        XCTAssertEqual(route(.readPhoto, device: false, online: true), Route(venue: .cloud, reason: .needsPhoto))
    }

    func testPhotoOfflineUsesTheLidarTemplate() {
        XCTAssertEqual(route(.readPhoto, device: true, online: false), Route(venue: .code, reason: .offlinePhotoTemplate))
        XCTAssertEqual(route(.readPhoto, device: false, online: false), Route(venue: .code, reason: .offlinePhotoTemplate))
    }

    func testPhotoIgnoresDeviceRejections() {
        XCTAssertEqual(route(.readPhoto, device: true, online: true, rejections: 5).venue, .cloud)
    }

    // MARK: - Every combination lands somewhere sensible

    func testEveryCombinationNeverSendsThePhotoToTheDeviceOrUsesTheCloudOffline() {
        for task in AITask.allCases {
            for device in [true, false] {
                for online in [true, false] {
                    for rejections in [0, 2, 3, 4] {
                        let route = route(task, device: device, online: online, rejections: rejections)
                        if task == .readPhoto { XCTAssertNotEqual(route.venue, .device) }
                        if !online { XCTAssertNotEqual(route.venue, .cloud) }
                        if route.venue == .device { XCTAssertTrue(device) }
                    }
                }
            }
        }
    }

    // MARK: - Screen text

    func testTheScreenTextMatchesThePlan() {
        XCTAssertEqual(RouteReason.numbersOnDevice.message, "Planned on this iPhone")
        XCTAssertEqual(RouteReason.needsPhoto.message, "Sent to Gemini: needs the photo")
        XCTAssertEqual(RouteReason.deviceFailedValidator.message,
                       "Sent to Gemini: the on-device plan failed the validator 3 times")
    }

    func testEveryReasonHasDistinctNonEmptyText() {
        let messages = RouteReason.allCases.map(\.message)
        XCTAssertFalse(messages.contains(where: \.isEmpty))
        XCTAssertEqual(Set(messages).count, messages.count)
    }
}
