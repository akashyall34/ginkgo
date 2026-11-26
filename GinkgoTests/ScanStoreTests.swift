import XCTest
@testable import Ginkgo

final class ScanStoreTests: XCTestCase {
    private var store = ScanStore(root: URL(fileURLWithPath: "/dev/null"))
    private let result = QuadResult(width: 0.1905, height: 0.12, uncertainty: 0.002, surfacePoints: 900,
                                    viewAngleDegrees: 12, widthEdgeGap: 0.001, heightEdgeGap: 0.0005)
    private let corners = [CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.8, y: 0.3),
                           CGPoint(x: 0.8, y: 0.7), CGPoint(x: 0.2, y: 0.7)]
    private let photo = Data([0xFF, 0xD8, 1, 2, 3])
    /// Distinct value at every pixel, so a reordered or truncated depth map can't pass.
    private let snapshot = makeSnapshot(depth: { x, y in 0.5 + Float(x) * 0.001 + Float(y) * 0.0001 },
                                        confidence: { x, y in UInt8((x + y) % 3) })

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = ScanStore(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.root)
    }

    @discardableResult
    private func save(_ id: UUID = UUID(), date: Date = Date(timeIntervalSince1970: 1_000)) throws -> SavedScan {
        try store.save(ScanCapture(photo: photo, snapshot: snapshot, corners: corners, result: result), id: id, date: date)
    }

    private func file(_ name: String, of id: UUID) -> URL {
        store.root.appendingPathComponent(id.uuidString).appendingPathComponent(name)
    }

    func testSaveThenLoadGivesBackExactlyWhatWasSaved() throws {
        let saved = try save()
        let loaded = try store.load(saved.id)
        XCTAssertEqual(loaded.scan, saved)
        XCTAssertEqual(loaded.scan.result, result)
        XCTAssertEqual(loaded.scan.corners, corners)
        XCTAssertEqual(loaded.scan.date, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(loaded.photo, photo)
        XCTAssertEqual(loaded.snapshot.width, 192)
        XCTAssertEqual(loaded.snapshot.height, 144)
        XCTAssertEqual(loaded.snapshot.depth, snapshot.depth, "Depth must survive bit for bit")
        XCTAssertEqual(loaded.snapshot.confidence, snapshot.confidence)
        XCTAssertEqual(loaded.snapshot.intrinsics, testIntrinsics)
    }

    func testPreviewLoadsSavedMetadataAndPhoto() throws {
        let saved = try save()
        let preview = try store.preview(saved.id)
        XCTAssertEqual(preview.scan, saved)
        XCTAssertEqual(preview.photo, photo)
    }

    func testAReloadedScanMeasuresTheSame() throws {
        // A flat face 50 cm away, which the measurer accepts.
        let flat = makeSnapshot(depth: { _, _ in 0.5 })
        let saved = try store.save(ScanCapture(photo: photo, snapshot: flat, corners: corners, result: result), id: UUID(), date: Date())
        let loaded = try store.load(saved.id)
        let raw = DetectedQuad(corners: corners).rawCorners
        let original = try QuadMeasurer.measure(corners: raw, in: flat).get()
        XCTAssertEqual(try QuadMeasurer.measure(corners: raw, in: loaded.snapshot).get(), original)
        XCTAssertGreaterThan(original.width, 0)
    }

    func testListIsNewestFirst() throws {
        let old = try save(date: Date(timeIntervalSince1970: 100))
        let new = try save(date: Date(timeIntervalSince1970: 300))
        let middle = try save(date: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(store.list().map(\.id), [new.id, middle.id, old.id])
    }

    func testEmptyOrMissingStoreListsNothing() {
        XCTAssertEqual(store.list(), [])
    }

    func testSavingAgainReplacesTheScan() throws {
        let id = UUID()
        try save(id)
        let moved = corners.map { CGPoint(x: $0.x + 0.01, y: $0.y) }
        try store.save(ScanCapture(photo: Data([9]), snapshot: snapshot, corners: moved, result: result),
                       id: id, date: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(store.list().count, 1)
        let loaded = try store.load(id)
        XCTAssertEqual(loaded.scan.corners, moved)
        XCTAssertEqual(loaded.photo, Data([9]))
    }

    func testDeleteRemovesTheScanAndItsFiles() throws {
        let keep = try save()
        let gone = try save()
        try store.delete(gone.id)
        XCTAssertEqual(store.list().map(\.id), [keep.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.appendingPathComponent(gone.id.uuidString).path))
        XCTAssertThrowsError(try store.load(gone.id)) { XCTAssertEqual($0 as? ScanStoreError, .notFound) }
    }

    func testASaveThatCantBeEncodedLeavesNothingBehindAndAnUnknownPreviewIsNotFound() throws {
        let broken = QuadResult(width: .nan, height: 0.12, uncertainty: 0.002, surfacePoints: 900, viewAngleDegrees: 12,
                                widthEdgeGap: 0, heightEdgeGap: 0)
        XCTAssertThrowsError(try store.save(ScanCapture(photo: photo, snapshot: snapshot, corners: corners, result: broken),
                                            id: UUID(), date: Date()))
        let left = try FileManager.default.contentsOfDirectory(atPath: store.root.path)
        XCTAssertEqual(left, [], "The half-written scan's folder is removed")
        XCTAssertThrowsError(try store.preview(UUID())) { XCTAssertEqual($0 as? ScanStoreError, .notFound) }
    }

    func testDeleteOrLoadOfAnUnknownScanIsNotFound() {
        XCTAssertThrowsError(try store.delete(UUID())) { XCTAssertEqual($0 as? ScanStoreError, .notFound) }
        XCTAssertThrowsError(try store.load(UUID())) { XCTAssertEqual($0 as? ScanStoreError, .notFound) }
    }

    func testEachMissingFileIsReportedNotCrashed() throws {
        for name in [ScanStore.scanFile, ScanStore.photoFile, ScanStore.depthFile, ScanStore.confidenceFile] {
            let saved = try save()
            try FileManager.default.removeItem(at: file(name, of: saved.id))
            XCTAssertThrowsError(try store.load(saved.id), name) { error in
                guard case .unreadable = error as? ScanStoreError else { return XCTFail("\(name): \(error)") }
            }
        }
    }

    func testTruncatedDepthOrConfidenceIsRejected() throws {
        for name in [ScanStore.depthFile, ScanStore.confidenceFile] {
            let saved = try save()
            let url = file(name, of: saved.id)
            try Data(contentsOf: url).dropLast().write(to: url)
            XCTAssertThrowsError(try store.load(saved.id), name) { error in
                guard case .unreadable = error as? ScanStoreError else { return XCTFail("\(name): \(error)") }
            }
        }
    }

    func testCorruptScanIsSkippedInTheListButOthersStillShow() throws {
        let good = try save()
        let bad = try save()
        try Data("not json".utf8).write(to: file(ScanStore.scanFile, of: bad.id))
        XCTAssertEqual(store.list().map(\.id), [good.id])
        XCTAssertThrowsError(try store.load(bad.id)) {
            XCTAssertEqual($0 as? ScanStoreError, .unreadable("scan.json can't be read"))
        }
    }

    func testAFailedSaveLeavesNoHalfWrittenScan() throws {
        // A file where the store folder should be makes every save fail.
        try Data().write(to: store.root)
        XCTAssertThrowsError(try save())
        XCTAssertEqual(store.list(), [])
    }

    func testNoStagingFoldersAreLeftBehind() throws {
        try save()
        let id = UUID()
        try save(id)
        try save(id)
        let names = try FileManager.default.contentsOfDirectory(atPath: store.root.path)
        XCTAssertEqual(names.filter { $0.hasPrefix(".") }, [])
        XCTAssertEqual(names.count, 2)
    }

    func testStandardStoreLivesInDocumentsScans() {
        XCTAssertEqual(ScanStore.standard().root.lastPathComponent, "Scans")
        XCTAssertEqual(ScanStore.standard().root.deletingLastPathComponent().lastPathComponent, "Documents")
    }
}
