import XCTest

/// The impact screen for the sample bench: numbers from the plan, then the sourced statistic.
@MainActor
final class ImpactUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testTheImpactScreenShowsThePlansNumbersAndTheSource() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "impact", "-noGemini"]
        app.launch()
        let any = app.descendants(matching: .any)
        let headline = any["impactHeadline"].firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        XCTAssertTrue(headline.label.contains("of the wood stays in use"), headline.label)
        XCTAssertTrue(any["impactArea"].firstMatch.label.contains("m² of panel reused"), any["impactArea"].firstMatch.label)
        XCTAssertTrue(any["impactPanels"].firstMatch.label.contains("panels used"))
        let fact = any["impactFact"].firstMatch
        XCTAssertTrue(fact.label.contains("9.7 million tons") && fact.label.contains("80.1%"), fact.label)
        XCTAssertTrue(any["impactSource"].firstMatch.exists, "The source is linked")
    }
}
