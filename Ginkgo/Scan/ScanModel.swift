import CoreGraphics
import Observation

/// Everything the Scan screen does, without any drawing: capture a frame, find the
/// faces in it, let the person pick or place a face's corners, and measure it.
@MainActor
@Observable
final class ScanModel {
    enum Status: Equatable {
        /// Live camera; nothing captured yet.
        case aiming
        /// Captured, and outlined faces are waiting to be picked.
        case chooseFace
        /// Captured, but no rectangular face was detected.
        case noFaceFound
        /// A corner is being dragged.
        case adjusting
        case measured(QuadResult)
        /// Something went wrong; the text says what to do.
        case problem(String)
    }

    let source: FrameSource
    private(set) var frame: CapturedFrame?
    private(set) var faces: [DetectedQuad] = []
    /// The corners being measured, normalized on the portrait photo; nil until a face is picked.
    private(set) var corners: [CGPoint]?
    private(set) var status: Status = .aiming

    static let crossedCornersMessage = "The corners cross. Drag them back into a four-sided shape."

    init(source: FrameSource) {
        self.source = source
    }

    var instruction: String { instruction(for: status) }

    func instruction(for status: Status) -> String {
        switch status {
        case .aiming: return "Aim at one flat face of the furniture, then capture."
        case .chooseFace: return "Tap the outlined face you want to measure."
        case .noFaceFound: return "No face found. Tap Place corners and drag them onto the face's corners."
        case .adjusting: return "Drag the corner onto the face's corner."
        case .measured(let result): return result.misplacedCornerHint ?? "Drag any corner to fine-tune."
        case .problem(let message): return message
        }
    }

    func capture() {
        switch source.capture() {
        case .success(let captured):
            frame = captured
            faces = captured.image.cgImage.map(RectangleDetector.detect) ?? []
            corners = nil
            status = faces.isEmpty ? .noFaceFound : .chooseFace
        case .failure(let error):
            status = .problem(error.explanation)
        }
    }

    /// Picks the smallest outlined face under the tap, so an inner face wins over an outer one.
    func selectFace(at point: CGPoint) {
        guard frame != nil, corners == nil else { return }
        let hits = faces.filter { $0.contains(point) }
        guard let face = hits.min(by: { RectangleDetector.area($0) < RectangleDetector.area($1) }) else { return }
        corners = face.corners
        measure()
    }

    func placeCornersManually() {
        guard frame != nil else { return }
        corners = DetectedQuad.manualStart.corners
        measure()
    }

    /// Moves one corner while dragging; the point is clamped to the photo.
    func moveCorner(_ index: Int, to point: CGPoint) {
        guard var current = corners, current.indices.contains(index) else { return }
        current[index] = CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        corners = current
        status = .adjusting
    }

    func finishMovingCorner() {
        measure()
    }

    func retake() {
        frame = nil
        faces = []
        corners = nil
        status = .aiming
    }

    private func measure() {
        guard let frame, let corners else { return }
        let face = DetectedQuad(corners: corners)
        guard face.isConvex else {
            status = .problem(Self.crossedCornersMessage)
            return
        }
        switch QuadMeasurer.measure(corners: face.rawCorners, in: frame.snapshot) {
        case .success(let result): status = .measured(result)
        case .failure(let error): status = .problem(error.explanation)
        }
    }
}
