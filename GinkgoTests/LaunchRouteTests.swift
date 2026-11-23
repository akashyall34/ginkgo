import XCTest
@testable import Ginkgo

final class LaunchRouteTests: XCTestCase {
    func testNoArgumentsOpensHome() {
        XCTAssertEqual(LaunchRoute(arguments: []), .home)
        XCTAssertEqual(LaunchRoute(arguments: ["/path/Ginkgo"]), .home)
    }

    func testEachKnownScreen() {
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "scan"]), .scan)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "example"]), .example)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "transform"]), .transform)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "contrast"]), .contrast)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "demo"]), .demo)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "parts"]), .parts)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "my-items"]), .myItems)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "recorded-run"]), .recordedRun)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "walk-around"]), .walkAround)
    }

    func testEveryRouteOpensByItsName() {
        for route in LaunchRoute.allCases {
            XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", route.rawValue]), route)
        }
    }

    func testFoundAmongOtherArguments() {
        let arguments = ["Ginkgo", "-demoScene", "-openScreen", "scan", "-UIPreferredContentSizeCategoryName", "L"]
        XCTAssertEqual(LaunchRoute(arguments: arguments), .scan)
    }

    func testUnknownScreenFallsBackToHome() {
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "nowhere"]), .home)
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen", "Scan"]), .home)
    }

    func testFlagWithoutValueFallsBackToHome() {
        XCTAssertEqual(LaunchRoute(arguments: ["Ginkgo", "-openScreen"]), .home)
    }
}
