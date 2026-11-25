import CoreGraphics
import Observation
import UIKit

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
    /// Where measurements are kept; nil keeps nothing (previews).
    let store: ScanStore?
    /// Lifts the furniture under a tap out of the background; nil turns one-tap lifting off.
    let lifter: SubjectLifting?
    /// The saved scan for the current capture; every new measurement of it replaces the save.
    private(set) var savedScanID: UUID?
    /// True when the last measurement couldn't be saved. The measurement itself still stands.
    private(set) var saveFailed = false
    private var photoData: Data?
    /// Flat-panel mode: the panel lies on the floor, and every measurement of its face also measures its thickness.
    let measuresThickness: Bool
    /// The panel's thickness from the same frame, in flat-panel mode once the face is measured.
    private(set) var thickness: ThicknessResult?
    /// Why the thickness couldn't be read, in flat-panel mode (the face's size still stands).
    private(set) var thicknessProblem: String?

    static let crossedCornersMessage = "The corners cross. Drag them back into a four-sided shape."

    init(source: FrameSource, store: ScanStore? = nil, lifter: SubjectLifting? = nil, measuresThickness: Bool = false) {
        self.source = source
        self.store = store
        self.lifter = lifter
        self.measuresThickness = measuresThickness
    }

    var instruction: String { instruction(for: status) }

    func instruction(for status: Status) -> String {
        switch status {
        case .aiming:
            return measuresThickness ? "Lay the panel flat on the floor. Hold the phone 30 to 50 cm above it, then capture."
                                     : "Aim at one flat face of the furniture, then capture."
        case .chooseFace: return "Tap the outlined face you want to measure, or tap the furniture to lift it out."
        case .noFaceFound: return "No outlined face. Tap the furniture to lift it out, or tap Place corners."
        case .adjusting: return "Drag the corner onto the face's corner."
        case .measured(let result): return result.misplacedCornerHint ?? "Drag any corner to fine-tune."
        case .problem(let message): return message
        }
    }

    func capture() {
        switch source.capture() {
        case .success(let captured):
            frame = captured
            savedScanID = nil
            photoData = nil
            saveFailed = false
            faces = captured.image.cgImage.map { RectangleDetector.detect(in: $0) } ?? []
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
        guard let face = hits.min(by: { RectangleDetector.area($0) < RectangleDetector.area($1) }) else {
            liftFace(at: point)
            return
        }
        corners = face.corners
        measure()
    }

    /// One tap: the subject under the finger is lifted out and its outline becomes the corners.
    private func liftFace(at point: CGPoint) {
        guard let lifter, let image = frame?.image.cgImage,
              let lifted = lifter.lift(from: image, at: point)?.corners,
              DetectedQuad(corners: lifted).isConvex else { return }
        corners = lifted
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
        savedScanID = nil
        photoData = nil
        saveFailed = false
        faces = []
        corners = nil
        thickness = nil
        thicknessProblem = nil
        status = .aiming
    }

    private func measure() {
        guard let frame, let corners else { return }
        let face = DetectedQuad(corners: corners)
        guard face.isConvex else {
            status = .problem(Self.crossedCornersMessage)
            return
        }
        thickness = nil
        thicknessProblem = nil
        switch QuadMeasurer.measure(corners: face.rawCorners, in: frame.snapshot) {
        case .success(let result):
            status = .measured(result)
            if measuresThickness { measureThickness(face, in: frame) }
            save(result, frame: frame, corners: corners)
        case .failure(let error): status = .problem(error.explanation)
        }
    }

    private func measureThickness(_ face: DetectedQuad, in frame: CapturedFrame) {
        switch ThicknessMeasurer.measure(corners: face.rawCorners, in: frame.snapshot) {
        case .success(let result): thickness = result
        case .failure(let error): thicknessProblem = error.explanation
        }
    }

    private func save(_ result: QuadResult, frame: CapturedFrame, corners: [CGPoint]) {
        guard let store else { return }
        let id = savedScanID ?? UUID()
        do {
            guard let photo = photoData ?? frame.image.heicData() else { throw ScanStoreError.unreadable("photo") }
            photoData = photo
            let saved = try store.save(ScanCapture(photo: photo, snapshot: frame.snapshot, corners: corners, result: result),
                                       id: id, date: Date())
            Task { await CloudBackup.shared.backUp(.piece(saved)) }
            savedScanID = id
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }
}
