import Foundation

/// A measured walk-around, kept for My items: the furniture's length × width × height and a photo.
struct SavedWalkAround: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    /// Meters.
    let length: Float
    let width: Float
    let height: Float
    let uncertainty: Float

    init(id: UUID = UUID(), date: Date = Date(), box: FittedBox) {
        self.id = id
        self.date = date
        length = box.length
        width = box.width
        height = box.height
        uncertainty = box.uncertainty
    }

    /// "42.4 × 29.9 × 32.2 cm" as length × width × height.
    var size: String { String(format: "%.1f × %.1f × %.1f cm", length * 100, width * 100, height * 100) }
    var plusMinus: String { String(format: "± %.1f cm", max(uncertainty, 0.001) * 100) }
}

/// Walk-around scans on the phone, one folder each: scan.json and photo.jpg. Nothing leaves the device.
struct WalkAroundStore {
    let root: URL

    static func standard() -> WalkAroundStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return WalkAroundStore(root: documents.appendingPathComponent("WalkAroundScans", isDirectory: true))
    }

    private func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }

    func save(_ scan: SavedWalkAround, photo: Data?) throws {
        let dir = folder(scan.id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(scan).write(to: dir.appendingPathComponent("scan.json"))
        if let photo { try photo.write(to: dir.appendingPathComponent("photo.jpg")) }
    }

    /// Every readable walk-around, newest first; damaged ones are skipped.
    func list() -> [SavedWalkAround] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { dir in
            (try? Data(contentsOf: dir.appendingPathComponent("scan.json"))).flatMap { try? decoder.decode(SavedWalkAround.self, from: $0) }
        }.sorted { $0.date > $1.date }
    }

    func photo(_ id: UUID) -> Data? { try? Data(contentsOf: folder(id).appendingPathComponent("photo.jpg")) }

    func delete(_ id: UUID) throws { try FileManager.default.removeItem(at: folder(id)) }
}
