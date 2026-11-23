import XCTest

/// Opens every screen in light and dark mode, at normal and the largest accessibility text size,
/// screenshots it, and runs Apple's accessibility audit (contrast, clipped text, dynamic type,
/// tap targets, labels). Issues are recorded as attachments and printed, for review.
final class UIAuditUITests: XCTestCase {
    private static let screens = ["home", "scan", "example", "transform", "contrast", "demo", "parts", "my-items",
                                  "guide", "settings", "ideas", "planning", "verify", "recorded-run", "walk-around"]
    private static let largestText = "UICTContentSizeCategoryAccessibilityXXXL"

    @MainActor
    func testAuditEveryScreen() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GINKGO_UI_AUDIT"] == "1",
                          "Run with GINKGO_UI_AUDIT=1; this sweep is for review, not every CI run")
        var report: [String] = []
        // GINKGO_UI_AUDIT_APPEARANCE=dark audits only dark mode (set the simulator with `simctl ui <device> appearance dark`).
        let only = ProcessInfo.processInfo.environment["GINKGO_UI_AUDIT_APPEARANCE"]
        let appearances: [XCUIDevice.Appearance] = only == "dark" ? [.dark] : only == "light" ? [.light] : [.light, .dark]
        for appearance in appearances {
            XCUIDevice.shared.appearance = appearance
            for large in [false, true] {
                // GINKGO_UI_AUDIT_SCREENS=verify,ideas re-checks just those screens after a fix.
                let only = ProcessInfo.processInfo.environment["GINKGO_UI_AUDIT_SCREENS"]?.split(separator: ",").map(String.init)
                for screen in only ?? Self.screens {
                    report += audit(screen, appearance: appearance, large: large)
                }
            }
        }
        XCUIDevice.shared.appearance = .light
        let text = report.isEmpty ? "No issues" : report.joined(separator: "\n")
        let attachment = XCTAttachment(string: text)
        attachment.name = "audit-report"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("UI AUDIT REPORT BEGIN\n\(text)\nUI AUDIT REPORT END")
    }

    @MainActor
    private func audit(_ screen: String, appearance: XCUIDevice.Appearance, large: Bool) -> [String] {
        let app = XCUIApplication()
        app.launchArguments += ["-demoScene", "-noGemini"]
        if screen != "home" { app.launchArguments += ["-openScreen", screen] }
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.largestText] }
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        sleep(2) // let the screen settle (animations, demo data)
        let tag = "\(screen)-\(appearance == .dark ? "dark" : "light")-\(large ? "xxxl" : "default")"
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = tag
        shot.lifetime = .keepAlways
        add(shot)
        var issues: [String] = []
        do {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' id='\($0.identifier)'" } ?? "-"
                issues.append("\(tag) | \(issue.auditType) | \(issue.compactDescription) | \(element)")
                return true // record, don't fail: this is a review sweep
            }
        } catch {
            issues.append("\(tag) | audit error | \(error)")
        }
        app.terminate()
        return issues
    }
}
