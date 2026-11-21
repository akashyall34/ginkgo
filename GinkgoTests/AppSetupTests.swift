import GinkgoCore
import UIKit
import XCTest
@testable import Ginkgo

final class AppSetupTests: XCTestCase {
    private func info(_ key: String) -> Any? { Bundle.main.object(forInfoDictionaryKey: key) }

    func testIdentity() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.akashy.ginkgo")
        XCTAssertEqual(info("CFBundleDisplayName") as? String, "Ginkgo")
    }

    func testCameraPermissionExplainsWhy() throws {
        let text = try XCTUnwrap(info("NSCameraUsageDescription") as? String)
        XCTAssertTrue(text.contains("measure"), "The permission prompt should say why: \(text)")
    }

    func testLaunchScreenUsesTheBrandBackground() throws {
        let launch = try XCTUnwrap(info("UILaunchScreen") as? [String: Any])
        XCTAssertEqual(launch["UIColorName"] as? String, "LaunchBackground")
    }

    func testAppIconIsBundled() {
        let icons = info("CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primary?["CFBundleIconName"] as? String, "AppIcon")
    }

    func testFirebaseIsOptionalUntilItsConfigExists() {
        // Configuring with or without the config file must never crash.
        FirebaseSetup.configureIfAvailable()
        FirebaseSetup.configureIfAvailable()
    }
}

final class DesignSystemTests: XCTestCase {
    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    /// The color's actual values in one appearance. Catalog colors are dynamic, so they
    /// must be resolved before comparing or measuring them.
    private func color(_ name: String, _ traits: UITraitCollection) throws -> UIColor {
        let dynamic = try XCTUnwrap(UIColor(named: name, in: .main, compatibleWith: traits), "Missing color \(name)")
        return dynamic.resolvedColor(with: traits)
    }

    private func components(_ c: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    func testEveryNamedColorExistsInLightAndDark() throws {
        for name in Palette.allNames {
            let l = try color(name, light), d = try color(name, dark)
            XCTAssertNotEqual(components(l), components(d), "\(name) needs a separate dark-mode version")
        }
    }

    func testResolvedColorsMatchTheDesignedValues() throws {
        // Brand green: #2F6B2A in light mode, #8FD18A in dark mode.
        let l = components(try color("Brand", light)), d = components(try color("Brand", dark))
        XCTAssertEqual(l[0], 0x2F / 255.0, accuracy: 0.01); XCTAssertEqual(l[1], 0x6B / 255.0, accuracy: 0.01)
        XCTAssertEqual(d[0], 0x8F / 255.0, accuracy: 0.01); XCTAssertEqual(d[1], 0xD1 / 255.0, accuracy: 0.01)
    }

    func testForegroundColorsMeetWCAGContrastOnTheBackground() throws {
        // WCAG AA: at least 4.5:1 for normal text.
        for traits in [light, dark] {
            let background = try color("LaunchBackground", traits)
            for name in Palette.foregroundNames {
                let ratio = Contrast.ratio(try color(name, traits), background)
                let mode = traits.userInterfaceStyle == .dark ? "dark" : "light"
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) on background is \(ratio):1 in \(mode) mode")
            }
        }
    }

    func testContrastFormulaKnownValues() {
        XCTAssertEqual(Contrast.ratio(.black, .white), 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio(.white, .white), 1, accuracy: 0.001)
        // #767676 on white is the classic AA threshold, about 4.54:1.
        let gray = UIColor(red: 0x76 / 255.0, green: 0x76 / 255.0, blue: 0x76 / 255.0, alpha: 1)
        XCTAssertEqual(Contrast.ratio(gray, .white), 4.54, accuracy: 0.02)
    }

    func testSpacingIsOnTheFourPointGridAndTapTargetMeetsHIG() {
        for s in [Spacing.xSmall, Spacing.small, Spacing.medium, Spacing.large, Spacing.xLarge] {
            XCTAssertEqual(s.truncatingRemainder(dividingBy: 4), 0)
        }
        XCTAssertGreaterThanOrEqual(TapTarget.minimum, 44)
    }
}

final class ModelTests: XCTestCase {
    private func example(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("examples/\(name).json"))
    }

    func testDecodesTheExamples() throws {
        let inv = try JSONDecoder().decode(Inventory.self, from: example("inventory"))
        XCTAssertEqual(inv.parts.count, 4)
        XCTAssertEqual(inv.parts[0].material, .solidWood)
        let plan = try JSONDecoder().decode(Plan.self, from: example("plan_chatbot"))
        XCTAssertEqual(plan.source, .chatbot)
        XCTAssertEqual(plan.newParts.count, 4)
    }

    func testBadDataFailsLoudly() throws {
        let json = try XCTUnwrap(String(bytes: try example("inventory"), encoding: .utf8))
            .replacingOccurrences(of: "\"solid_wood\"", with: "\"oak\"")
        XCTAssertThrowsError(try JSONDecoder().decode(Inventory.self, from: Data(json.utf8)))
    }
}
