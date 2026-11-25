import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

/// Sign in with Google through Firebase Auth. The anonymous user is linked to the Google account, so its backups
/// carry over; if that Google account already has a Ginkgo user, the app signs in to it instead.
struct FirebaseAccount: AccountService {
    static func ifConfigured() -> FirebaseAccount? {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return nil }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        return FirebaseAccount()
    }

    func currentEmail() async -> String? {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        return user.email
    }

    @MainActor
    func signInWithGoogle() async throws -> String {
        guard let presenter = Self.topController() else { throw CocoaError(.userCancelled) }
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            throw CancellationError()
        }
        guard let idToken = result.user.idToken?.tokenString else { throw CocoaError(.coderValueNotFound) }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: result.user.accessToken.tokenString)
        let user: User
        if let anonymous = Auth.auth().currentUser, anonymous.isAnonymous {
            do {
                user = try await anonymous.link(with: credential).user
            } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                user = try await Auth.auth().signIn(with: credential).user
            }
        } else {
            user = try await Auth.auth().signIn(with: credential).user
        }
        return user.email ?? result.user.profile?.email ?? "your Google account"
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    @MainActor
    private static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
