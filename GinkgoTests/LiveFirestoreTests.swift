import FirebaseAuth
import FirebaseFirestore
import XCTest
@testable import Ginkgo

/// One real backup through Firebase: anonymous sign-in, a write, a read back, and a delete.
/// Run by scripts/check-live-ai.sh only (needs the network, the Firebase config and the console setup).
final class LiveFirestoreTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GINKGO_LIVE_AI"] == "1", "Live Firebase check only")
        await MainActor.run { FirebaseSetup.configureIfAvailable() }
    }

    func testABackupRecordReachesFirestoreUnderTheSignedInUser() async throws {
        let documents = try XCTUnwrap(FirestoreDocuments.ifConfigured(), "Firebase isn't configured")
        let uid = try await documents.signIn()
        XCTAssertFalse(uid.isEmpty)
        let id = "live-check-\(UUID().uuidString)"
        try await documents.write(collection: "pieces", id: id, json: Data(#"{"widthMm": 400, "heightMm": 300}"#.utf8))
        let doc = Firestore.firestore().collection("users").document(uid).collection("pieces").document(id)
        let read = try await doc.getDocument()
        XCTAssertEqual(read.data()?["widthMm"] as? Int, 400)
        try await doc.delete()
    }
}
