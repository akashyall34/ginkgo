import ARKit
import XCTest
@testable import Ginkgo

/// A camera that returns whatever the test scripts.
@MainActor
private final class ScriptedSource: FrameSource {
    var result: Result<CapturedFrame, CaptureError>
    var started = 0, paused = 0
    init(_ result: Result<CapturedFrame, CaptureError>) { self.result = result }
    var isSupported: Bool { true }
    var previewSession: ARSession? { nil }
    func start() { started += 1 }
    func pause() { paused += 1 }
    func capture() -> Result<CapturedFrame, CaptureError> { result }
}

@MainActor
final class ScanModelTests: XCTestCase {
    private func demoFrame() throws -> CapturedFrame { try XCTUnwrap(DemoScene.frame()) }

    /// The demo face's center, on the portrait photo.
    private var faceCenter: CGPoint {
        let c = DemoScene.portraitCorners
        return CGPoint(x: c.map(\.x).reduce(0, +) / 4, y: c.map(\.y).reduce(0, +) / 4)
    }

    private func measured(_ model: ScanModel) throws -> QuadResult {
        guard case .measured(let r) = model.status else {
            XCTFail("Expected a measurement, got \(model.status)")
            throw XCTSkip("no measurement")
        }
        return r
    }

    // MARK: capture

    func testStartsAimingWithNothingCaptured() {
        let model = ScanModel(source: DemoFrameSource())
        XCTAssertEqual(model.status, .aiming)
        XCTAssertNil(model.frame)
        XCTAssertFalse(model.instruction.isEmpty)
    }

    func testCaptureFindsTheDemoFace() {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        XCTAssertNotNil(model.frame)
        XCTAssertEqual(model.status, .chooseFace)
        XCTAssertFalse(model.faces.isEmpty)
        XCTAssertNil(model.corners, "Nothing is measured until a face is picked")
    }

    func testCaptureFailureExplainsWhatToDo() {
        for error in [CaptureError.noFrameYet, .noDepth, .unreadableFrame] {
            let model = ScanModel(source: ScriptedSource(.failure(error)))
            model.capture()
            XCTAssertEqual(model.status, .problem(error.explanation))
            XCTAssertNil(model.frame)
        }
    }

    func testAFrameWithNoFacesSaysSoAndOffersPlacingCorners() throws {
        // The demo depth with a blank photo: nothing for Vision to find.
        let demo = try demoFrame()
        let blank = CapturedFrame(image: UIImage(), confidenceOverlay: demo.confidenceOverlay, snapshot: demo.snapshot)
        let model = ScanModel(source: ScriptedSource(.success(blank)))
        model.capture()
        XCTAssertEqual(model.status, .noFaceFound)
        XCTAssertTrue(model.instruction.contains("Place corners"))
    }

    // MARK: picking and measuring

    func testTappingTheFaceMeasuresItsKnownSize() throws {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: faceCenter)
        let r = try measured(model)
        XCTAssertEqual(r.width, DemoScene.widthMeters, accuracy: 0.002)
        XCTAssertEqual(r.height, DemoScene.heightMeters, accuracy: 0.002)
        XCTAssertEqual(model.corners?.count, 4)
    }

    func testTappingOutsideAnyFaceChangesNothing() {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: CGPoint(x: 0.02, y: 0.02))
        XCTAssertEqual(model.status, .chooseFace)
        XCTAssertNil(model.corners)
    }

    func testOnceMeasuringTapsDoNotReselect() throws {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: faceCenter)
        let before = model.corners
        model.selectFace(at: faceCenter)
        XCTAssertEqual(model.corners, before)
    }

    func testTapsBeforeCaptureAreIgnored() {
        let model = ScanModel(source: DemoFrameSource())
        model.selectFace(at: faceCenter)
        model.placeCornersManually()
        XCTAssertNil(model.corners)
        XCTAssertEqual(model.status, .aiming)
    }

    // MARK: corners

    func testDraggingTheRightEdgeOutwardWidensTheFace() throws {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: faceCenter)
        let before = try measured(model).width
        for i in [1, 2] { // top-right, bottom-right
            let c = try XCTUnwrap(model.corners)[i]
            model.moveCorner(i, to: CGPoint(x: c.x + 0.03, y: c.y))
            XCTAssertEqual(model.status, .adjusting)
            model.finishMovingCorner()
        }
        XCTAssertGreaterThan(try measured(model).width, before + 0.005)
    }

    func testDraggingPastThePhotoEdgeStopsAtTheEdge() throws {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.placeCornersManually()
        model.moveCorner(1, to: CGPoint(x: 1.7, y: -0.4))
        XCTAssertEqual(model.corners?[1], CGPoint(x: 1, y: 0))
    }

    func testCrossedCornersAreRefusedWithAWarning() throws {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: faceCenter)
        let bottomRight = try XCTUnwrap(model.corners)[2]
        model.moveCorner(0, to: CGPoint(x: bottomRight.x + 0.05, y: bottomRight.y + 0.05))
        model.finishMovingCorner()
        XCTAssertEqual(model.status, .problem(ScanModel.crossedCornersMessage))
    }

    func testAnInvalidCornerIndexIsIgnored() {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.placeCornersManually()
        let before = model.corners
        model.moveCorner(7, to: .zero)
        XCTAssertEqual(model.corners, before)
    }

    func testPlacedCornersOverPlainDepthStillMeasure() throws {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.placeCornersManually()
        XCTAssertGreaterThan(try measured(model).width, 0)
    }

    func testAMeasurementThatCannotBeTrustedIsExplained() throws {
        // Low-confidence depth everywhere: the face can't be measured.
        let demo = try demoFrame()
        let s = demo.snapshot
        let unreliable = try XCTUnwrap(DepthSnapshot(width: s.width, height: s.height, depth: s.depth,
                                                     confidence: Array(repeating: 0, count: s.confidence.count),
                                                     intrinsics: s.intrinsics))
        let frame = CapturedFrame(image: demo.image, confidenceOverlay: demo.confidenceOverlay, snapshot: unreliable)
        let model = ScanModel(source: ScriptedSource(.success(frame)))
        model.capture()
        model.selectFace(at: faceCenter)
        guard case .problem(let message) = model.status else { return XCTFail("Expected a problem, got \(model.status)") }
        XCTAssertTrue(message.contains("reliable"), message)
    }

    // MARK: retake and messages

    func testRetakeClearsEverything() {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: faceCenter)
        model.retake()
        XCTAssertNil(model.frame)
        XCTAssertTrue(model.faces.isEmpty)
        XCTAssertNil(model.corners)
        XCTAssertEqual(model.status, .aiming)
    }

    func testEveryStatusHasAnInstruction() throws {
        let r = QuadResult(width: 0.2, height: 0.1, uncertainty: 0.002, surfacePoints: 500, viewAngleDegrees: 10)
        let all: [ScanModel.Status] = [.aiming, .chooseFace, .noFaceFound, .adjusting, .measured(r), .problem("Fix it.")]
        let model = ScanModel(source: DemoFrameSource())
        for status in all {
            XCTAssertFalse(model.instruction(for: status).isEmpty, "\(status)")
        }
        XCTAssertEqual(model.instruction(for: .problem("Fix it.")), "Fix it.")
    }

    func testDefaultSourceIsTheRealCameraUnlessTheDemoIsRequested() {
        // Unit tests don't pass -demoScene, so the default is the real LiDAR camera.
        XCTAssertTrue(FrameSources.makeDefault() is DepthCapture)
    }

    func testDemoSourceIsSupportedWithNoLivePreview() {
        let s = DemoFrameSource()
        s.start(); s.pause()
        XCTAssertTrue(s.isSupported)
        XCTAssertNil(s.previewSession)
    }
}

final class MeasurementFormatTests: XCTestCase {
    func testSizeInCentimetersWithOneDecimal() {
        XCTAssertEqual(MeasurementFormat.size(widthMeters: 0.4583, heightMeters: 0.3961), "45.8 × 39.6 cm")
    }

    func testInches() {
        XCTAssertEqual(MeasurementFormat.inches(widthMeters: 0.1905, heightMeters: 0.254), "7.5 × 10.0 in")
    }

    func testPlusMinus() {
        XCTAssertEqual(MeasurementFormat.plusMinus(meters: 0.0034), "± 0.3 cm")
    }

    func testSpokenForVoiceOver() {
        XCTAssertEqual(MeasurementFormat.spoken(widthMeters: 0.458, heightMeters: 0.396, uncertaintyMeters: 0.003),
                       "45.8 by 39.6 centimeters, plus or minus 0.3")
    }
}
