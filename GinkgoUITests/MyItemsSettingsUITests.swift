import XCTest

@MainActor
final class MyItemsSettingsUITests: XCTestCase {
    private func gearOpens(_ tab: String?, _ app: XCUIApplication) -> Bool {
        if let tab { app.buttons[tab].tap() }
        sleep(1)
        app.buttons.matching(identifier: "appearanceSettings").firstMatch.tap()
        let opened = app.buttons["appearance-dark"].waitForExistence(timeout: 4)
        if opened {
            if app.buttons["appearanceDone"].exists {
                app.buttons["appearanceDone"].tap()
            } else {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            }
            sleep(1)
        }
        return opened
    }

    func testTheGearOnEveryTab() {
        let app = XCUIApplication()
        app.launchSkippingFirstRun()
        let home = gearOpens(nil, app)
        let guide = gearOpens("Guide", app)
        let items = gearOpens("My items", app)
        print("GEAR home=\(home) guide=\(guide) items=\(items)")
        XCTAssertTrue(home && guide && items)
    }
}
