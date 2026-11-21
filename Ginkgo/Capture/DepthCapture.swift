import ARKit
import CoreImage
import UIKit

enum CaptureError: Error, Equatable {
    /// The camera hasn't delivered a frame yet.
    case noFrameYet
    /// The frame has no LiDAR depth (still starting, or covered).
    case noDepth
    /// The frame's data couldn't be read.
    case unreadableFrame

    var explanation: String {
        switch self {
        case .noFrameYet: return "The camera is still starting. Try again in a moment."
        case .noDepth: return "No LiDAR depth in this frame. Hold steady, uncover the camera, and try again."
        case .unreadableFrame: return "Couldn't read this frame. Try again."
        }
    }
}

/// Runs the AR session and copies one frame's photo and depth on demand. This is
/// thin glue over ARKit, checked on a real iPhone; the conversions it relies on are
/// in FrameConversion and are unit tested.
@MainActor
final class DepthCapture {
    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    let session = ARSession()
    private let ciContext = CIContext()

    func start() {
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .sceneDepth
        session.run(config)
    }

    func pause() {
        session.pause()
    }

    func capture() -> Result<CapturedFrame, CaptureError> {
        guard let frame = session.currentFrame else { return .failure(.noFrameYet) }
        guard let sceneDepth = frame.sceneDepth, let confidenceMap = sceneDepth.confidenceMap else {
            return .failure(.noDepth)
        }
        guard let depth = FrameConversion.depthValues(sceneDepth.depthMap),
              let confidence = FrameConversion.confidenceValues(confidenceMap),
              let snapshot = DepthSnapshot(width: depth.width, height: depth.height,
                                           depth: depth.values, confidence: confidence.values,
                                           intrinsics: FrameConversion.intrinsics(
                                               from: frame.camera.intrinsics,
                                               imageResolution: frame.camera.imageResolution)) else {
            return .failure(.unreadableFrame)
        }

        let upright = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)
        guard let photo = ciContext.createCGImage(upright, from: upright.extent),
              let overlay = UIImage.confidenceOverlay(for: snapshot, context: ciContext) else {
            return .failure(.unreadableFrame)
        }
        return .success(CapturedFrame(image: UIImage(cgImage: photo), confidenceOverlay: overlay, snapshot: snapshot))
    }
}
