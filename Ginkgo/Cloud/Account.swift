import Foundation
import Observation

/// Who the backup belongs to. `FirebaseAccount` is the real one; tests pass a fake.
protocol AccountService: Sendable {
    /// The signed-in Google email, or nil while the user is anonymous or signed out.
    func currentEmail() async -> String?
    /// Signs in with Google and keeps what was backed up anonymously; returns the email.
    func signInWithGoogle() async throws -> String
    func signOut() async throws
}

/// The account line in Settings: anonymous backup by default, Sign in with Google to use the same backup on every
/// iPhone.
@MainActor
@Observable
final class AccountModel {
    enum State: Equatable {
        case anonymous
        case signingIn
        case signedIn(email: String)
        case failed(String)
    }

    /// The app's account, made after Firebase is configured at launch.
    static let shared = AccountModel(service: FirebaseAccount.ifConfigured())

    private(set) var state: State = .anonymous
    private let service: (any AccountService)?

    init(service: (any AccountService)?) { self.service = service }

    var isAvailable: Bool { service != nil }

    var line: String {
        switch state {
        case .anonymous: return "Not signed in. Backups stay with this iPhone."
        case .signingIn: return "Signing in with Google…"
        case .signedIn(let email): return "Signed in as \(email). Your backup follows you to any iPhone."
        case .failed(let why): return "Couldn't sign in: \(why)"
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    func refresh() async {
        guard let service else { return }
        if let email = await service.currentEmail() { state = .signedIn(email: email) } else { state = .anonymous }
    }

    func signIn() async {
        guard let service, state != .signingIn else { return }
        state = .signingIn
        do {
            state = .signedIn(email: try await service.signInWithGoogle())
        } catch is CancellationError {
            state = .anonymous
        } catch {
            state = .failed(CloudBackup.plain(error))
        }
    }

    func signOut() async {
        guard let service else { return }
        do {
            try await service.signOut()
            state = .anonymous
        } catch {
            state = .failed(CloudBackup.plain(error))
        }
    }
}
