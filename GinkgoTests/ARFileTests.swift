import RealityKit
import XCTest

/// "View in AR" depends on RealityKit writing a Reality file (what AR Quick Look opens) that can be opened again.
@MainActor
final class ARFileTests: XCTestCase {
    @available(iOS 18.0, *)
    func testABuildIsWrittenAsARealityFileAndReadsBack() async throws {
        let build = Entity()
        build.addChild(ModelEntity(mesh: .generateBox(width: 0.4, height: 0.3, depth: 0.019),
                                   materials: [SimpleMaterial(color: .brown, isMetallic: false)]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).reality")
        defer { try? FileManager.default.removeItem(at: url) }
        try await build.write(to: url)
        let size = try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        XCTAssertGreaterThan(size, 100)
        let reloaded = try await Entity(contentsOf: url)
        XCTAssertNotNil(reloaded)
    }
}
