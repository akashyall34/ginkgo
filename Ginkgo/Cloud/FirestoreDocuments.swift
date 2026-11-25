import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Backups in Firestore at users/{uid}/{collection}/{id}, signed in anonymously. Sign in with Apple can later be
/// linked to the same user, so nothing backed up now is lost.
struct FirestoreDocuments: CloudDocuments {
    /// Nil when Firebase isn't configured (no GoogleService-Info.plist in this build).
    static func ifConfigured() -> FirestoreDocuments? {
        FirebaseApp.app() == nil ? nil : FirestoreDocuments()
    }

    func signIn() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        return try await Auth.auth().signInAnonymously().user.uid
    }

    func write(collection: String, id: String, json: Data) async throws {
        let uid = try await signIn()
        guard let fields = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            throw CocoaError(.coderInvalidValue)
        }
        try await Firestore.firestore().collection("users").document(uid).collection(collection).document(id)
            .setData(fields)
    }
}
