import simd
import XCTest
@testable import Ginkgo

final class WalkAroundRecordingTests: XCTestCase {
    func testARecordingRoundTripsExactly() throws {
        let points = [SIMD3<Float>(0.1, 0.2, 0.3), SIMD3(-1, 0.5, 2)]
        let recording = WalkAroundRecording(points: points, floorY: -1.2, aim: SIMD3(0, 0.4, 0.1))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try XCTUnwrap(recording.save(in: folder, at: Date(timeIntervalSince1970: 0)))
        XCTAssertEqual(url.lastPathComponent, "1970-01-01T00-00-00Z.json")
        let loaded = try JSONDecoder().decode(WalkAroundRecording.self, from: Data(contentsOf: url))
        XCTAssertEqual(loaded, recording)
        XCTAssertEqual(loaded.worldPoints, points)
        XCTAssertEqual(loaded.aimPoint, SIMD3(0, 0.4, 0.1))
        XCTAssertEqual(loaded.floorY, -1.2)
    }

    func testMissingFloorAndAimStayMissing() {
        let recording = WalkAroundRecording(points: [], floorY: nil, aim: nil)
        XCTAssertNil(recording.floorY)
        XCTAssertNil(recording.aimPoint)
        XCTAssertEqual(recording.worldPoints, [])
    }

    func testAnUnwritableFolderIsIgnored() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertNil(WalkAroundRecording(points: [], floorY: 0, aim: nil).save(in: file))
    }
}

final class WalkAroundRecordingCloudTests: XCTestCase {
    func testTheDepthCloudIsKeptWithTheRecording() throws {
        let cloud = [SIMD3<Float>(0.1, 0.2, 0.3), SIMD3(0.4, 0.5, 0.6)]
        let recording = WalkAroundRecording(points: [], floorY: 0, aim: nil, cloud: cloud)
        let loaded = try JSONDecoder().decode(WalkAroundRecording.self, from: JSONEncoder().encode(recording))
        XCTAssertEqual(loaded.cloudPoints, cloud)
        XCTAssertNil(WalkAroundRecording(points: [], floorY: 0, aim: nil).cloud, "No depth, no cloud field")
    }
}
