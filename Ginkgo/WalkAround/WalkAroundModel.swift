import Foundation
import Observation
import simd

/// The walk-around scan without the camera: turn a room mesh into the furniture's W × H × D.
@MainActor
@Observable
final class WalkAroundModel {
    enum Status: Equatable {
        case scanning
        case measured(FittedBox)
        case problem(String)
    }

    private(set) var status: Status = .scanning

    static let noFloorMessage = "The floor wasn't found. Tilt the phone down so the floor around the furniture is scanned."
    static let noAimMessage = "Point the dot at the furniture, then tap Done."
    static let nothingThereMessage = "Nothing scanned where the dot points. Aim the dot at the furniture and try again."

    var instruction: String {
        switch status {
        case .scanning: return "Walk slowly around the furniture. Keep it in view until it's covered, then aim the dot at it and tap Done."
        case .measured: return "Measured from every side."
        case .problem(let message): return message
        }
    }

    /// Measures the furniture under the aim point.
    /// `cloud` is the raw depth gathered while walking; when there's enough of it the mesh box is re-fitted on it.
    func finish(points: [SIMD3<Float>], floorY: Float?, aim: SIMD3<Float>?, cloud: [SIMD3<Float>] = []) {
        guard let floorY else { return status = .problem(Self.noFloorMessage) }
        guard let aim else { return status = .problem(Self.noAimMessage) }
        let furniture = FurnitureIsolation.isolate(points, seed: aim, floorY: floorY)
        guard !furniture.isEmpty else { return status = .problem(Self.nothingThereMessage) }
        do {
            let coarse = try BoxFit.fit(furniture, floorY: floorY)
            status = .measured(BoxFit.refine(coarse, cloud: cloud) ?? coarse)
        } catch {
            status = .problem(error.explanation)
        }
    }

    func rescan() { status = .scanning }

    /// Mesh points a typical piece of furniture needs before the box fit is dependable.
    static let readyPoints = 3000

    /// How much has been scanned, 0...1, from the room mesh's size.
    static func coverage(points: Int) -> Double {
        min(max(Double(points) / Double(readyPoints), 0), 1)
    }

    /// What to tell the person while they walk.
    static func progressText(points: Int) -> String {
        switch coverage(points: points) {
        case ..<0.4: return "Keep walking around it"
        case ..<1: return "Almost there: cover the sides you haven't seen"
        default: return "Ready: aim the dot at it and tap Done"
        }
    }

    /// "46.0 × 40.0 × 58.0 cm ± 0.3 cm": length × width × height.
    static func summary(_ box: FittedBox) -> String {
        String(format: "%.1f × %.1f × %.1f cm ± %.1f cm", box.length * 100, box.width * 100, box.height * 100,
               max(box.uncertainty, 0.001) * 100)
    }
}
