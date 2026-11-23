import XCTest
@testable import Ginkgo

@MainActor
final class FrameSourceTests: XCTestCase {
    // MARK: - Choosing a source

    func testDemoModeUsesTheDemoScene() {
        XCTAssertTrue(FrameSources.makeDefault(demo: true) is DemoFrameSource)
    }

    func testOtherwiseTheRealLiDARCameraIsUsed() {
        let source = FrameSources.makeDefault(demo: false)
        XCTAssertTrue(source is DepthCapture)
        // The simulator has no LiDAR, so the real camera reports it can't measure (the designed fallback state).
        XCTAssertFalse(source.isSupported)
    }

    // MARK: - The demo source

    func testTheDemoSceneAlwaysMeasuresAndHasNoCameraPreview() {
        let demo = DemoFrameSource()
        XCTAssertTrue(demo.isSupported)
        XCTAssertNil(demo.previewSession)
        demo.start()
        demo.pause()
    }

    func testTheDemoSceneCapturesAFrame() throws {
        let frame = try DemoFrameSource().capture().get()
        XCTAssertGreaterThan(frame.snapshot.width, 0)
    }

    func testAnUnreadableDemoFrameIsReportedAsAnError() {
        XCTAssertEqual(DemoFrameSource(makeFrame: { nil }).capture().failure, .unreadableFrame)
    }
}

private extension Result {
    var failure: Failure? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
