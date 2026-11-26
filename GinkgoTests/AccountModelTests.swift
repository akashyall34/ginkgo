import XCTest
@testable import Ginkgo

/// A stand-in for Google sign-in.
private final class FakeAccount: AccountService, @unchecked Sendable {
    var email: String?
    var failure: Error?
    var signOutFailure: Error?
    var signIns = 0
    func currentEmail() async -> String? { email }
    func signInWithGoogle() async throws -> String {
        signIns += 1
        if let failure { throw failure }
        email = "maker@example.com"
        return "maker@example.com"
    }
    func signOut() async throws {
        if let signOutFailure { throw signOutFailure }
        email = nil
    }
}

@MainActor
final class AccountModelTests: XCTestCase {
    func testStartsAnonymousAndSaysBackupsStayWithThisIPhone() async {
        let model = AccountModel(service: FakeAccount())
        await model.refresh()
        XCTAssertEqual(model.state, .anonymous)
        XCTAssertEqual(model.line, "Not signed in. Backups stay with this iPhone.")
        XCTAssertFalse(model.isSignedIn)
    }

    func testAnEarlierSignInIsRememberedAtLaunch() async {
        let fake = FakeAccount()
        fake.email = "maker@example.com"
        let model = AccountModel(service: fake)
        await model.refresh()
        XCTAssertEqual(model.state, .signedIn(email: "maker@example.com"))
    }

    func testSigningInShowsTheAccountAndSigningOutReturnsToAnonymous() async {
        let model = AccountModel(service: FakeAccount())
        await model.signIn()
        XCTAssertEqual(model.line, "Signed in as maker@example.com. New backups are saved to this account.")
        XCTAssertTrue(model.isSignedIn)
        await model.signOut()
        XCTAssertEqual(model.state, .anonymous)
    }

    func testCancellingTheGooglePageIsNotAnError() async {
        let fake = FakeAccount()
        fake.failure = CancellationError()
        let model = AccountModel(service: fake)
        await model.signIn()
        XCTAssertEqual(model.state, .anonymous)
    }

    func testAFailureSaysWhy() async {
        struct Offline: LocalizedError { var errorDescription: String? { "the network is offline" } }
        let fake = FakeAccount()
        fake.failure = Offline()
        let model = AccountModel(service: fake)
        await model.signIn()
        XCTAssertEqual(model.line, "Couldn't sign in: the network is offline")
    }

    func testASignOutThatFailsSaysWhyAndStaysSignedIn() async {
        struct Offline: LocalizedError { var errorDescription: String? { "the network is offline" } }
        let fake = FakeAccount()
        let model = AccountModel(service: fake)
        await model.signIn()
        fake.signOutFailure = Offline()
        await model.signOut()
        XCTAssertEqual(model.line, "Couldn't sign in: the network is offline")
        XCTAssertFalse(model.isSignedIn)
    }

    func testWithoutFirebaseThereIsNoAccountToSignInTo() async {
        let model = AccountModel(service: nil)
        XCTAssertFalse(model.isAvailable)
        await model.signIn()
        await model.refresh()
        XCTAssertEqual(model.state, .anonymous)
    }
}
