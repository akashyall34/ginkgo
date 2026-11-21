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
    func finish(points: [SIMD3<Float>], floorY: Float?, aim: SIMD3<Float>?) {
        guard let floorY else { return status = .problem(Self.noFloorMessage) }
        guard let aim else { return status = .problem(Self.noAimMessage) }
        let furniture = FurnitureIsolation.isolate(points, seed: aim, floorY: floorY)
        guard !furniture.isEmpty else { return status = .problem(Self.nothingThereMessage) }
        do {
            status = .measured(try BoxFit.fit(furniture, floorY: floorY))
        } catch let error as BoxFitError {
            status = .problem(error.explanation)
        } catch {
            status = .problem(Self.nothingThereMessage)
        }
    }

    func rescan() { status = .scanning }

    /// "46.0 × 58.0 × 40.0 cm ± 0.3 cm" as width × height × depth, the order the plan uses.
    static func summary(_ box: FittedBox) -> String {
        String(format: "%.1f × %.1f × %.1f cm ± %.1f cm", box.width * 100, box.height * 100, box.depth * 100,
               max(box.uncertainty, 0.001) * 100)
    }
}
