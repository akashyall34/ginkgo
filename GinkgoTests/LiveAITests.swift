import FirebaseAILogic
import FirebaseCore
import XCTest
@testable import Ginkgo

/// One real call to Gemini through Firebase. Skipped in normal CI so a busy Google
/// server can't fail the build. Run it with: scripts/check-live-ai.sh
final class LiveAITests: XCTestCase {
    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["GINKGO_LIVE_AI"] == "1" else {
            throw XCTSkip("Live AI check runs only via scripts/check-live-ai.sh")
        }
        FirebaseSetup.configureIfAvailable()
    }

    func testGeminiReturnsJSONMatchingTheSchema() async throws {
        XCTAssertTrue(FirebaseSetup.isConfigFilePresent, "GoogleService-Info.plist is not bundled")
        let schema = Schema.object(properties: [
            "panels": .array(items: .object(properties: [
                "name": .string(),
                "width_mm": .double(),
            ])),
        ])
        let text = try await GeminiClient().json(
            prompt: "A nightstand is 460 mm wide and 560 mm tall. List its top and one side panel with widths in mm.",
            schema: schema)
        let reply = try JSONDecoder().decode(PanelReply.self, from: Data(text.utf8))
        XCTAssertFalse(reply.panels.isEmpty, "Gemini returned no panels: \(text)")
        XCTAssertTrue(reply.panels.allSatisfy { $0.widthMM > 0 }, text)
    }
}

private struct PanelReply: Decodable {
    let panels: [PanelSize]
}

private struct PanelSize: Decodable {
    let name: String
    let widthMM: Double

    enum CodingKeys: String, CodingKey {
        case name
        case widthMM = "width_mm"
    }
}
