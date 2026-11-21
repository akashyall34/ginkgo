import CoreGraphics
import Foundation

/// What's remembered about one scan, written as scan.json beside its photo and depth.
struct SavedScan: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    /// The measured face's corners, normalized on the portrait photo.
    let corners: [CGPoint]
    let result: QuadResult
    let intrinsics: Intrinsics
    let depthWidth: Int
    let depthHeight: Int
}

/// What one measurement produced, ready to be saved.
struct ScanCapture {
    let photo: Data
    let snapshot: DepthSnapshot
    let corners: [CGPoint]
    let result: QuadResult
}

/// A scan read back from disk: everything needed to show it again or re-measure it.
struct LoadedScan {
    let scan: SavedScan
    let photo: Data
    let snapshot: DepthSnapshot
}

enum ScanStoreError: Error, Equatable {
    case notFound
    case unreadable(String)
}

/// Keeps scans on the phone, one folder per scan:
/// scan.json, photo.heic, depth.bin (Float32) and confidence.bin (UInt8).
/// Nothing leaves the device.
struct ScanStore {
    let root: URL

    static let scanFile = "scan.json"
    static let photoFile = "photo.heic"
    static let depthFile = "depth.bin"
    static let confidenceFile = "confidence.bin"

    /// Documents/Scans, the store the app uses.
    static func standard() -> ScanStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return ScanStore(root: documents.appendingPathComponent("Scans", isDirectory: true))
    }

    private func folder(_ id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    /// Writes a scan, replacing any earlier save with the same id. A half-written save
    /// never replaces a good one: files go to a temporary folder that is swapped in at the end.
    @discardableResult
    func save(_ capture: ScanCapture, id: UUID, date: Date) throws -> SavedScan {
        let (photo, snapshot) = (capture.photo, capture.snapshot)
        let scan = SavedScan(id: id, date: date, corners: capture.corners, result: capture.result, intrinsics: snapshot.intrinsics,
                             depthWidth: snapshot.width, depthHeight: snapshot.height)
        let files = FileManager.default
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent(".\(id.uuidString)-\(UUID().uuidString)", isDirectory: true)
        try files.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(scan).write(to: staging.appendingPathComponent(Self.scanFile))
            try photo.write(to: staging.appendingPathComponent(Self.photoFile))
            try snapshot.depth.withUnsafeBufferPointer { Data(buffer: $0) }
                .write(to: staging.appendingPathComponent(Self.depthFile))
            try Data(snapshot.confidence).write(to: staging.appendingPathComponent(Self.confidenceFile))
            let target = folder(id)
            if files.fileExists(atPath: target.path) {
                _ = try files.replaceItemAt(target, withItemAt: staging)
            } else {
                try files.moveItem(at: staging, to: target)
            }
        } catch {
            try? files.removeItem(at: staging)
            throw error
        }
        return scan
    }

    /// Every readable scan, newest first. Damaged folders are skipped, not fatal.
    func list() -> [SavedScan] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return folders
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .compactMap { try? readScan(in: $0) }
            .sorted { $0.date > $1.date }
    }

    func load(_ id: UUID) throws -> LoadedScan {
        let dir = folder(id)
        guard FileManager.default.fileExists(atPath: dir.path) else { throw ScanStoreError.notFound }
        let scan = try readScan(in: dir)
        let photo = try read(Self.photoFile, in: dir)
        let count = scan.depthWidth * scan.depthHeight
        let depthData = try read(Self.depthFile, in: dir)
        let confidence = try read(Self.confidenceFile, in: dir)
        guard depthData.count == count * MemoryLayout<Float>.size else {
            throw ScanStoreError.unreadable("depth.bin has the wrong size")
        }
        let depth = depthData.withUnsafeBytes { raw in
            (0..<count).map { raw.loadUnaligned(fromByteOffset: $0 * MemoryLayout<Float>.size, as: Float.self) }
        }
        guard let snapshot = DepthSnapshot(width: scan.depthWidth, height: scan.depthHeight, depth: depth,
                                           confidence: [UInt8](confidence), intrinsics: scan.intrinsics) else {
            throw ScanStoreError.unreadable("confidence.bin has the wrong size")
        }
        return LoadedScan(scan: scan, photo: photo, snapshot: snapshot)
    }

    func delete(_ id: UUID) throws {
        let dir = folder(id)
        guard FileManager.default.fileExists(atPath: dir.path) else { throw ScanStoreError.notFound }
        try FileManager.default.removeItem(at: dir)
    }

    private func readScan(in dir: URL) throws -> SavedScan {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(SavedScan.self, from: read(Self.scanFile, in: dir))
        } catch let error as ScanStoreError {
            throw error
        } catch {
            throw ScanStoreError.unreadable("scan.json can't be read")
        }
    }

    private func read(_ name: String, in dir: URL) throws -> Data {
        do {
            return try Data(contentsOf: dir.appendingPathComponent(name))
        } catch {
            throw ScanStoreError.unreadable("\(name) is missing")
        }
    }
}
