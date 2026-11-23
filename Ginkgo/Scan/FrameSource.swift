import ARKit

/// Where scan frames come from: the real LiDAR camera, or the built-in demo scene.
/// The Scan screen's logic only talks to this, so it can be tested without a camera.
@MainActor
protocol FrameSource: AnyObject {
    /// Whether this device can measure (has LiDAR, or is the demo).
    var isSupported: Bool { get }
    /// The AR session to show as a live preview, if there is one.
    var previewSession: ARSession? { get }
    func start()
    func pause()
    func capture() -> Result<CapturedFrame, CaptureError>
}

/// Serves the demo scene: a known 19.05 x 12 cm face, for the simulator and demo mode.
@MainActor
final class DemoFrameSource: FrameSource {
    private let makeFrame: () -> CapturedFrame?

    /// `makeFrame` is the demo scene; tests pass a failing one.
    init(makeFrame: @escaping () -> CapturedFrame? = DemoScene.frame) {
        self.makeFrame = makeFrame
    }

    var isSupported: Bool { true }
    var previewSession: ARSession? { nil }
    func start() {}
    func pause() {}

    func capture() -> Result<CapturedFrame, CaptureError> {
        makeFrame().map(Result.success) ?? .failure(.unreadableFrame)
    }
}

enum FrameSources {
    /// The demo scene when launched with `-demoScene`, otherwise the real camera.
    @MainActor
    static func makeDefault(demo: Bool = DemoScene.isEnabled) -> FrameSource {
        demo ? DemoFrameSource() : DepthCapture()
    }
}
