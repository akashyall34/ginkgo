import XCTest

/// Backup is opt-in: Settings shows the switch off, and says what would leave the phone.
@MainActor
final class BackupSettingsUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testBackupIsOffByDefaultAndSaysWhatStaysOnThePhone() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "settings", "-noGemini", "-cloudBackupEnabled", "NO"]
        app.launch()
        let toggle = app.switches["backupToggle"].firstMatch
        if !toggle.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0", "Off until the person turns it on")
        let status = app.staticTexts["backupStatus"].firstMatch
        XCTAssertTrue(status.label.hasPrefix("Off.") || status.label == "Not available in this build.", status.label)
        let privacy = NSPredicate(format: "label CONTAINS %@", "Photos and depth maps stay on this iPhone")
        XCTAssertTrue(app.staticTexts.matching(privacy).firstMatch.exists)
    }
}
