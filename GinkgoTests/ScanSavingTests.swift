import XCTest
@testable import Ginkgo

/// Every measurement on the Scan screen is kept, one saved scan per capture.
@MainActor
final class ScanSavingTests: XCTestCase {
    private var store = ScanStore(root: URL(fileURLWithPath: "/dev/null"))

    override func setUp() async throws {
        store = ScanStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: store.root)
    }

    private var faceCenter: CGPoint {
        let c = DemoScene.portraitCorners
        return CGPoint(x: c.map(\.x).reduce(0, +) / 4, y: c.map(\.y).reduce(0, +) / 4)
    }

    private func measuredModel() -> ScanModel {
        let model = ScanModel(source: DemoFrameSource(), store: store)
        model.capture()
        model.selectFace(at: faceCenter)
        return model
    }

    func testAMeasurementIsSavedWithItsPhotoAndDepth() throws {
        let model = measuredModel()
        guard case .measured(let result) = model.status else { return XCTFail("\(model.status)") }
        let id = try XCTUnwrap(model.savedScanID)
        XCTAssertFalse(model.saveFailed)
        let loaded = try store.load(id)
        XCTAssertEqual(loaded.scan.result, result)
        XCTAssertEqual(loaded.scan.corners, model.corners)
        XCTAssertEqual(loaded.snapshot.depth, model.frame?.snapshot.depth)
        XCTAssertNotNil(UIImage(data: loaded.photo), "The saved photo must be a readable image")
    }

    func testAdjustingACornerUpdatesTheSameSave() throws {
        let model = measuredModel()
        let id = try XCTUnwrap(model.savedScanID)
        let corner = try XCTUnwrap(model.corners?[0])
        model.moveCorner(0, to: CGPoint(x: corner.x - 0.01, y: corner.y))
        model.finishMovingCorner()
        XCTAssertEqual(model.savedScanID, id)
        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(try store.load(id).scan.corners, model.corners)
    }

    func testANewCaptureIsANewSave() throws {
        let model = measuredModel()
        let first = try XCTUnwrap(model.savedScanID)
        model.retake()
        XCTAssertNil(model.savedScanID)
        model.capture()
        model.selectFace(at: faceCenter)
        XCTAssertNotEqual(model.savedScanID, first)
        XCTAssertEqual(store.list().count, 2)
    }

    func testAFailedMeasurementSavesNothing() throws {
        let model = measuredModel()
        let id = try XCTUnwrap(model.savedScanID)
        let valid = try XCTUnwrap(model.corners)
        // Swapping two neighboring corners crosses the shape, so it can't be measured.
        model.moveCorner(0, to: valid[1])
        model.moveCorner(1, to: valid[0])
        model.finishMovingCorner()
        XCTAssertEqual(model.status, .problem(ScanModel.crossedCornersMessage))
        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(try store.load(id).scan.corners, valid, "The last good measurement stays saved")
    }

    func testWithoutAStoreNothingIsSaved() {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: faceCenter)
        XCTAssertNil(model.savedScanID)
        XCTAssertFalse(model.saveFailed)
    }

    func testASaveFailureKeepsTheMeasurement() throws {
        try Data().write(to: store.root) // a file where the folder should be
        let model = measuredModel()
        guard case .measured = model.status else { return XCTFail("\(model.status)") }
        XCTAssertTrue(model.saveFailed)
        XCTAssertNil(model.savedScanID)
    }
}
