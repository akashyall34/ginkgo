import GinkgoCore
import XCTest
@testable import Ginkgo

final class RemoteSettingsTests: XCTestCase {
    override func tearDown() {
        RemoteSettings.apply(models: nil, numbers: [:])
        super.tearDown()
    }

    func testAModelListReplacesTheBuiltInOne() {
        XCTAssertEqual(RemoteSettings.models(from: "gemini-4.0-flash, gemini-3.5-flash-lite"),
                       ["gemini-4.0-flash", "gemini-3.5-flash-lite"])
    }

    func testAnEmptyOrOddListKeepsTheBuiltInModels() {
        XCTAssertEqual(RemoteSettings.models(from: ""), AIRunner.builtInModels)
        XCTAssertEqual(RemoteSettings.models(from: " , "), AIRunner.builtInModels)
        XCTAssertEqual(RemoteSettings.models(from: "gemini-4.0-flash, gpt-5"), AIRunner.builtInModels,
                       "One name that isn't a Gemini model rejects the whole list")
        XCTAssertEqual(RemoteSettings.models(from: "Gemini 4"), AIRunner.builtInModels)
    }

    func testOnlyKnownNumericKeysReachTheValidator() {
        let settings = RemoteSettings.validator(from: ["validator_margin_mm": 10, "validator_seat_load_kg": nil,
                                                       "unrelated": 99])
        XCTAssertEqual(settings.remote, [.marginMm: 10])
    }

    func testApplyingChangesTheModelsAndTheValidatorAndNilRestoresThem() {
        RemoteSettings.apply(models: "gemini-4.0-flash", numbers: ["validator_margin_mm": 10])
        XCTAssertEqual(AIRunner.standard.models, ["gemini-4.0-flash"])
        XCTAssertEqual(GeminiAgentModel().modelName, "gemini-4.0-flash")
        XCTAssertEqual(Packer.margin, 10)
        RemoteSettings.apply(models: nil, numbers: [:])
        XCTAssertEqual(AIRunner.standard.models, AIRunner.builtInModels)
        XCTAssertEqual(Packer.margin, 8)
    }

    func testALooserRemoteMarginNeverReachesThePacker() {
        RemoteSettings.apply(models: nil, numbers: ["validator_margin_mm": 1])
        XCTAssertEqual(Packer.margin, 8)
    }
}
