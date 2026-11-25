import XCTest

extension XCUIApplication {
    /// Launches with the first-run guide already seen, so tests that open Home go straight to it. UserDefaults reads
    /// `-hasSeenFirstRunGuide YES` from the launch arguments for this launch only.
    func launchSkippingFirstRun() {
        launchArguments += ["-hasSeenFirstRunGuide", "YES"]
        launch()
    }
}
