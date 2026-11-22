import XCTest
@testable import Ginkgo

final class WalkAroundStoreTests: XCTestCase {
    private var store = WalkAroundStore(root: URL(fileURLWithPath: "/dev/null"))
    private let box = FittedBox(length: 0.424, width: 0.299, height: 0.322, baseCenter: .zero, yaw: 0,
                                uncertainty: 0.004, pointCount: 2_000)
    private let photo = Data([0xFF, 0xD8, 9, 8, 7])

    override func setUpWithError() throws {
        store = WalkAroundStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.root)
    }

    private func scan(_ seconds: TimeInterval, id: UUID = UUID()) -> SavedWalkAround {
        SavedWalkAround(id: id, date: Date(timeIntervalSince1970: seconds), box: box)
    }

    // MARK: - SavedWalkAround

    func testItKeepsTheBoxSizes() {
        let saved = scan(0)
        XCTAssertEqual(saved.length, 0.424)
        XCTAssertEqual(saved.width, 0.299)
        XCTAssertEqual(saved.height, 0.322)
        XCTAssertEqual(saved.uncertainty, 0.004)
    }

    func testSizeReadsLengthByWidthByHeightInCentimeters() {
        XCTAssertEqual(scan(0).size, "42.4 × 29.9 × 32.2 cm")
    }

    func testPlusMinusInCentimeters() {
        XCTAssertEqual(scan(0).plusMinus, "± 0.4 cm")
    }

    func testPlusMinusNeverShowsZero() {
        let exact = SavedWalkAround(box: FittedBox(length: 1, width: 1, height: 1, baseCenter: .zero, yaw: 0,
                                                   uncertainty: 0, pointCount: 2_000))
        XCTAssertEqual(exact.plusMinus, "± 0.1 cm")
    }

    // MARK: - Save, list, photo, delete

    func testAnEmptyStoreListsNothing() {
        XCTAssertEqual(store.list(), [])
    }

    func testASavedScanComesBackUnchanged() throws {
        let saved = scan(1_000)
        try store.save(saved, photo: photo)
        XCTAssertEqual(store.list(), [saved])
        XCTAssertEqual(store.photo(saved.id), photo)
    }

    func testAScanWithoutAPhotoHasNoPhoto() throws {
        let saved = scan(1_000)
        try store.save(saved, photo: nil)
        XCTAssertEqual(store.list(), [saved])
        XCTAssertNil(store.photo(saved.id))
    }

    func testTheListIsNewestFirst() throws {
        let old = scan(1_000), new = scan(3_000), middle = scan(2_000)
        for item in [old, new, middle] { try store.save(item, photo: nil) }
        XCTAssertEqual(store.list().map(\.id), [new.id, middle.id, old.id])
    }

    func testSavingTheSameIdAgainReplacesIt() throws {
        let id = UUID()
        try store.save(scan(1_000, id: id), photo: photo)
        try store.save(scan(2_000, id: id), photo: Data([1]))
        XCTAssertEqual(store.list().map(\.date), [Date(timeIntervalSince1970: 2_000)])
        XCTAssertEqual(store.photo(id), Data([1]))
    }

    func testADamagedScanIsSkippedAndTheRestStillList() throws {
        let good = scan(1_000), bad = scan(2_000)
        try store.save(good, photo: nil)
        try store.save(bad, photo: nil)
        try Data("not json".utf8).write(to: store.root.appendingPathComponent(bad.id.uuidString)
            .appendingPathComponent("scan.json"))
        XCTAssertEqual(store.list(), [good])
    }

    func testAFolderWithNoScanFileIsSkipped() throws {
        try FileManager.default.createDirectory(at: store.root.appendingPathComponent("stray"),
                                                withIntermediateDirectories: true)
        XCTAssertEqual(store.list(), [])
    }

    func testDeleteRemovesTheScanAndItsPhoto() throws {
        let keep = scan(1_000), gone = scan(2_000)
        try store.save(keep, photo: photo)
        try store.save(gone, photo: photo)
        try store.delete(gone.id)
        XCTAssertEqual(store.list(), [keep])
        XCTAssertNil(store.photo(gone.id))
        XCTAssertEqual(store.photo(keep.id), photo)
    }

    func testDeletingAMissingScanThrows() {
        XCTAssertThrowsError(try store.delete(UUID()))
    }

    func testThePhotoOfAnUnknownIdIsNil() {
        XCTAssertNil(store.photo(UUID()))
    }

    func testTheStandardStoreLivesInDocuments() {
        let root = WalkAroundStore.standard().root
        XCTAssertEqual(root.lastPathComponent, "WalkAroundScans")
        XCTAssertEqual(root.deletingLastPathComponent().lastPathComponent, "Documents")
    }
}
