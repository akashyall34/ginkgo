import GinkgoCore
import XCTest
@testable import Ginkgo

@MainActor
final class TakeApartModelTests: XCTestCase {
    private func inventory() throws -> Inventory {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        return try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
    }

    private let photo = Data([0xFF, 0xD8])

    private func answer(_ inventory: Inventory) -> String {
        let ids = inventory.parts.map { "\"\($0.id)\"" }.joined(separator: ",")
        return #"{"steps":[{"part_ids":[\#(ids)],"action":"Undo the screws.","fastener":"screws"}]}"#
    }

    func testOfflineUsesTheTemplateAndNeverCallsGemini() async throws {
        let model = TakeApartModel(inventory: try inventory(), photo: photo)
        var called = false
        await model.load(online: false, modelName: "g") { _, _ in called = true; return "" }
        XCTAssertFalse(called)
        XCTAssertEqual(model.guide?.source, .template)
        XCTAssertEqual(model.sourceLine, "Ginkgo's standard order for these parts")
        XCTAssertEqual(model.entry?.venue, .code)
        XCTAssertEqual(model.entry?.reason, .offlinePhotoTemplate)
    }

    func testNoPhotoUsesTheTemplate() async throws {
        let model = TakeApartModel(inventory: try inventory(), photo: nil)
        await model.load(online: true, modelName: "g") { _, _ in XCTFail("No photo to send"); return "" }
        XCTAssertEqual(model.guide?.source, .template)
    }

    func testOnlineGeminiReadsThePhotoWithThePartsList() async throws {
        let inventory = try inventory()
        let model = TakeApartModel(inventory: inventory, photo: photo)
        var sent: (String, Data)?
        await model.load(online: true, modelName: "gemini-test") { prompt, image in
            sent = (prompt, image)
            return self.answer(inventory)
        }
        XCTAssertEqual(sent?.1, photo)
        XCTAssertTrue(sent?.0.contains("- \(inventory.parts[0].id):") ?? false)
        XCTAssertEqual(model.guide?.source, .gemini)
        XCTAssertEqual(model.guide?.steps.last?.action, "Undo the screws.")
        XCTAssertEqual(model.sourceLine, "Read by Gemini from your photo, checked against your parts")
        XCTAssertEqual(model.entry?.model, "gemini-test")
        XCTAssertEqual(model.entry?.verdict, .passed)
        XCTAssertEqual(model.entry?.venue, .cloud)
    }

    func testAnUnreachableGeminiFallsBackAndSaysSo() async throws {
        struct Offline: Error {}
        let model = TakeApartModel(inventory: try inventory(), photo: photo)
        await model.load(online: true, modelName: "g") { _, _ in throw Offline() }
        XCTAssertEqual(model.guide?.source, .template)
        XCTAssertEqual(model.guide?.notes.first, TakeApartModel.unreachable)
        XCTAssertEqual(model.entry?.verdict, .failed)
        XCTAssertEqual(model.entry?.model, "template")
    }

    func testTickingStepsCountsProgressAndUnticks() async throws {
        let model = TakeApartModel(inventory: try inventory(), photo: nil)
        XCTAssertTrue(model.isLoading)
        await model.load(online: false, modelName: "g") { _, _ in "" }
        let total = try XCTUnwrap(model.guide?.steps.count)
        XCTAssertEqual(model.progress, "0 of \(total) done")
        model.toggle(1)
        model.toggle(2)
        XCTAssertEqual(model.progress, "2 of \(total) done")
        model.toggle(1)
        XCTAssertEqual(model.done, [2])
    }
}
