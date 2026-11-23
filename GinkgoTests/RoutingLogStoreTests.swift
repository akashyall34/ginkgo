import GinkgoCore
import XCTest
@testable import Ginkgo

final class RoutingLogStoreTests: XCTestCase {
    private var store = RoutingLogStore(url: URL(fileURLWithPath: "/dev/null"))

    override func setUpWithError() throws {
        store = RoutingLogStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("routing-log.jsonl"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent())
    }

    private func entry(_ venue: Venue, ms: Int) -> RoutingEntry {
        RoutingEntry(task: .planFromNumbers, venue: venue, reason: .numbersOnDevice, model: "m", durationMs: ms,
                     verdict: .passed, date: Date(timeIntervalSince1970: 1_795_300_000))
    }

    func testANewStoreIsEmpty() throws {
        XCTAssertEqual(try store.load(), RoutingLog())
    }

    func testEntriesAccumulateAcrossRunsInOrder() throws {
        try store.append([entry(.device, ms: 1)])
        try store.append([entry(.device, ms: 2), entry(.cloud, ms: 3)])
        XCTAssertEqual(try store.load().entries.map(\.durationMs), [1, 2, 3])
    }

    func testAppendingNothingWritesNothing() throws {
        try store.append([])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path))
    }

    func testADamagedLogIsNeverOverwritten() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xFF, 0xFE, 0x00]).write(to: store.url)
        XCTAssertThrowsError(try store.append([entry(.device, ms: 1)]))
        XCTAssertEqual(try Data(contentsOf: store.url), Data([0xFF, 0xFE, 0x00]), "The evidence is kept as it was")
    }

    func testTheStandardLogLivesInDocuments() {
        XCTAssertEqual(RoutingLogStore.standard().url.lastPathComponent, "routing-log.jsonl")
        XCTAssertEqual(RoutingLogStore.standard().url.deletingLastPathComponent().lastPathComponent, "Documents")
    }
}

final class ConnectivityTests: XCTestCase {
    func testOnceIsTrueOnlyTheFirstTime() {
        let once = Once()
        XCTAssertTrue(once.claim())
        XCTAssertFalse(once.claim())
        XCTAssertFalse(once.claim())
    }

    func testTheAnswerComesBackOnceAndQuickly() async {
        // The simulator shares the Mac's network; the point is that it answers (once) rather than hanging.
        let start = ContinuousClock.now
        _ = await Connectivity.isOnline()
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(5))
    }
}
