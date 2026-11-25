import GinkgoCore
import XCTest
@testable import Ginkgo

/// A stand-in for Firestore that records writes, or fails.
private final class FakeDocuments: CloudDocuments, @unchecked Sendable {
    var writes: [BackupRecord] = []
    var signIns = 0
    var failure: Error?
    func signIn() async throws -> String {
        signIns += 1
        if let failure { throw failure }
        return "user-1"
    }
    func write(collection: String, id: String, json: Data) async throws {
        if let failure { throw failure }
        writes.append(BackupRecord(collection: collection, id: id, json: json))
    }
}

@MainActor
final class CloudBackupTests: XCTestCase {
    /// A fresh store per test (XCTest makes a new instance for each), so no test sees another's choice.
    private let defaults = UserDefaults(suiteName: "CloudBackupTests-\(UUID().uuidString)") ?? .standard

    private func scan() -> SavedScan {
        SavedScan(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(), date: Date(timeIntervalSince1970: 0),
                  corners: [], result: QuadResult(width: 0.4004, height: 0.3, uncertainty: 0.002, surfacePoints: 900,
                                                  viewAngleDegrees: 12, widthEdgeGap: 0, heightEdgeGap: 0),
                  intrinsics: Intrinsics(fx: 1, fy: 1, cx: 0, cy: 0, imageWidth: 1, imageHeight: 1), depthWidth: 1, depthHeight: 1)
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testOffByDefaultAndNothingLeavesThePhone() async {
        let fake = FakeDocuments()
        let backup = CloudBackup(documents: fake, defaults: defaults)
        XCTAssertFalse(backup.isEnabled)
        await backup.backUp(.piece(scan()))
        XCTAssertTrue(fake.writes.isEmpty)
        XCTAssertEqual(fake.signIns, 0, "Not even a sign-in while it's off")
        XCTAssertEqual(backup.statusLine, "Off. Everything stays on this iPhone.")
    }

    func testTurningItOnBacksUpWhatsHereAndIsRemembered() async {
        let fake = FakeDocuments()
        let backup = CloudBackup(documents: fake, defaults: defaults)
        await backup.setEnabled(true, existing: [.piece(scan())])
        XCTAssertEqual(fake.writes.map(\.collection), ["pieces"])
        XCTAssertEqual(fake.writes.first?.id, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(backup.statusLine, "Backed up 1 item.")
        XCTAssertTrue(CloudBackup(documents: fake, defaults: defaults).isEnabled, "The choice survives a relaunch")
    }

    func testTurningItOffStopsBackups() async {
        let fake = FakeDocuments()
        let backup = CloudBackup(documents: fake, defaults: defaults)
        await backup.setEnabled(true)
        await backup.setEnabled(false)
        await backup.backUp(.piece(scan()))
        XCTAssertTrue(fake.writes.isEmpty)
        XCTAssertFalse(CloudBackup(documents: fake, defaults: defaults).isEnabled)
    }

    func testWithoutFirebaseItCantBeTurnedOn() async {
        let backup = CloudBackup(documents: nil, defaults: defaults)
        await backup.setEnabled(true)
        XCTAssertFalse(backup.isEnabled)
        XCTAssertEqual(backup.statusLine, "Not available in this build.")
    }

    func testAFailureSaysSoAndTheNextTrySucceeds() async {
        struct Offline: LocalizedError { var errorDescription: String? { "the network is offline" } }
        let fake = FakeDocuments()
        let backup = CloudBackup(documents: fake, defaults: defaults)
        await backup.setEnabled(true)
        fake.failure = Offline()
        await backup.backUp(.piece(scan()))
        XCTAssertEqual(backup.statusLine, "Couldn't back up: the network is offline. It will try again next time.")
        fake.failure = nil
        await backup.backUp(.piece(scan()))
        XCTAssertEqual(backup.statusLine, "Backed up 1 item.")
    }

    func testAPieceRecordHoldsOnlyTheMeasurementInMillimetres() throws {
        let fields = try object(BackupRecord.piece(scan()).json)
        XCTAssertEqual(Set(fields.keys), ["date", "widthMm", "heightMm", "uncertaintyMm", "viewAngleDegrees"],
                       "No photo, depth or corners")
        XCTAssertEqual(fields["widthMm"] as? Double, 400)
        XCTAssertEqual(fields["uncertaintyMm"] as? Double, 2)
        XCTAssertLessThanOrEqual(fields.count, 8, "Within the Firestore rule's field limit")
    }

    func testAPlanRecordSaysWhereItWasMadeAndThatItPassed() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
        let safe = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory))
        let record = BackupRecord.plan(safe.plan, validation: safe.validation,
                                       route: Route(venue: .device, reason: .numbersOnDevice), date: Date())
        XCTAssertEqual(record.collection, "plans")
        XCTAssertEqual(record.id, safe.plan.id)
        let fields = try object(record.json)
        XCTAssertEqual(fields["passes"] as? Bool, true)
        XCTAssertEqual(fields["venue"] as? String, "device")
        XCTAssertNotNil(fields["plan"] as? [String: Any])
        XCTAssertLessThanOrEqual(fields.count, 8)
    }
}

final class ConnectivityUpdatesTests: XCTestCase {
    func testTheUpdatesStartWithTheCurrentState() async {
        var iterator = Connectivity.updates().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertNotNil(first, "The stream reports whether the phone is online right away")
        let once = await Connectivity.isOnline()
        XCTAssertEqual(first, once, "Both ways of asking agree")
    }
}
