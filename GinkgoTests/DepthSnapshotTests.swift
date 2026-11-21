import XCTest
@testable import Ginkgo

final class DepthSnapshotTests: XCTestCase {
    private func snapshot(width: Int, height: Int, depthCount: Int? = nil, confidenceCount: Int? = nil) -> DepthSnapshot? {
        DepthSnapshot(width: width, height: height,
                      depth: Array(repeating: 1, count: depthCount ?? width * height),
                      confidence: Array(repeating: 2, count: confidenceCount ?? width * height),
                      intrinsics: testIntrinsics)
    }

    func testMatchingSizesMakeASnapshot() throws {
        let s = try XCTUnwrap(snapshot(width: 4, height: 3))
        XCTAssertEqual(s.width, 4)
        XCTAssertEqual(s.height, 3)
        XCTAssertEqual(s.depth.count, 12)
    }

    func testEmptyMapIsRejectedNotCrashed() {
        XCTAssertNil(snapshot(width: 0, height: 3))
        XCTAssertNil(snapshot(width: 4, height: 0))
    }

    func testMismatchedDepthIsRejected() {
        XCTAssertNil(snapshot(width: 4, height: 3, depthCount: 11))
    }

    func testMismatchedConfidenceIsRejected() {
        XCTAssertNil(snapshot(width: 4, height: 3, confidenceCount: 13))
    }
}
