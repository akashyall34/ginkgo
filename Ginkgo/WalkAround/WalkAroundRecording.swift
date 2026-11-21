import Foundation
import simd

/// One walk-around scan's raw input, kept on the phone so a real scan can be replayed in tests
/// and checked against a tape measure. Points are world space, meters, Float32 x y z.
struct WalkAroundRecording: Codable, Equatable {
    let floorY: Float?
    let aim: [Float]?
    let points: [Float]

    init(points: [SIMD3<Float>], floorY: Float?, aim: SIMD3<Float>?) {
        self.floorY = floorY
        self.aim = aim.map { [$0.x, $0.y, $0.z] }
        self.points = points.flatMap { [$0.x, $0.y, $0.z] }
    }

    var worldPoints: [SIMD3<Float>] {
        stride(from: 0, to: points.count - 2, by: 3).map { SIMD3(points[$0], points[$0 + 1], points[$0 + 2]) }
    }

    var aimPoint: SIMD3<Float>? {
        guard let aim, aim.count == 3 else { return nil }
        return SIMD3(aim[0], aim[1], aim[2])
    }

    /// Documents/WalkArounds, next to the saved scans.
    static func folder() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("WalkArounds", isDirectory: true)
    }

    /// Saves as JSON; failures are ignored because a recording is a diagnostic, never needed to measure.
    func save(in folder: URL = WalkAroundRecording.folder(), at date: Date = Date()) -> URL? {
        let name = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-") + ".json"
        let url = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(self).write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
