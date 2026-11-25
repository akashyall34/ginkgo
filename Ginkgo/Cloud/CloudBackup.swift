import Foundation
import GinkgoCore
import Observation

/// Where backups go: one record per id, in a collection, under the signed-in user. `FirestoreDocuments` is the real
/// one; tests pass a fake.
protocol CloudDocuments: Sendable {
    /// Signs in if needed (anonymously for now) and returns the user id.
    func signIn() async throws -> String
    func write(collection: String, id: String, json: Data) async throws
}

/// One record to back up: small, and never a photo or depth map.
struct BackupRecord: Equatable, Sendable {
    let collection: String
    let id: String
    let json: Data

    /// A measured piece: its size and how sure the measurement is.
    static func piece(_ scan: SavedScan) -> BackupRecord {
        struct Piece: Encodable {
            let date: Date
            let widthMm: Double
            let heightMm: Double
            let uncertaintyMm: Double
            let viewAngleDegrees: Double
        }
        let piece = Piece(date: scan.date, widthMm: mm(scan.result.width), heightMm: mm(scan.result.height),
                          uncertaintyMm: mm(scan.result.uncertainty),
                          viewAngleDegrees: Double(scan.result.viewAngleDegrees))
        return BackupRecord(collection: "pieces", id: scan.id.uuidString, json: encode(piece))
    }

    /// A plan the validator accepted, with its verdict and where it was made.
    static func plan(_ plan: Plan, validation: ValidationResult, route: Route?, date: Date) -> BackupRecord {
        struct Saved: Encodable {
            let date: Date
            let plan: Plan
            let passes: Bool
            let reusePercent: Double
            let venue: String?
            let reason: String?
        }
        let saved = Saved(date: date, plan: plan, passes: validation.passes, reusePercent: validation.reusePercent,
                          venue: route?.venue.rawValue, reason: route?.reason.rawValue)
        return BackupRecord(collection: "plans", id: plan.id, json: encode(saved))
    }

    private static func mm(_ meters: Float) -> Double { (Double(meters) * 1000).rounded() }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(value)) ?? Data("{}".utf8)
    }
}

/// Opt-in cloud backup of measurements and plans. Off until the person turns it on in Settings; then each new
/// measurement and accepted plan is written to Firestore under their (anonymous) user.
@MainActor
@Observable
final class CloudBackup {
    static let enabledKey = "cloudBackupEnabled"
    /// The app's backup, made after Firebase is configured at launch.
    static let shared = CloudBackup(documents: FirestoreDocuments.ifConfigured())

    enum Status: Equatable {
        case off
        case on
        case backedUp(count: Int)
        case failed(String)
    }

    private(set) var status: Status
    private(set) var backedUp = 0
    private let documents: (any CloudDocuments)?
    private let defaults: UserDefaults

    /// `documents` is nil when Firebase isn't set up in this build; backup then can't be turned on.
    init(documents: (any CloudDocuments)?, defaults: UserDefaults = .standard) {
        self.documents = documents
        self.defaults = defaults
        status = defaults.bool(forKey: Self.enabledKey) && documents != nil ? .on : .off
    }

    var isAvailable: Bool { documents != nil }
    var isEnabled: Bool { status != .off }

    /// What Settings shows under the switch.
    var statusLine: String {
        switch status {
        case .off: return isAvailable ? "Off. Everything stays on this iPhone." : "Not available in this build."
        case .on: return "On. New measurements and plans are backed up."
        case .backedUp(let count): return count == 1 ? "Backed up 1 item." : "Backed up \(count) items."
        case .failed(let why): return "Couldn't back up: \(why). It will try again next time."
        }
    }

    /// Turning it on backs up what's already here; turning it off stops new backups (nothing is deleted).
    func setEnabled(_ on: Bool, existing: [BackupRecord] = []) async {
        guard on, documents != nil else {
            defaults.set(false, forKey: Self.enabledKey)
            status = .off
            return
        }
        defaults.set(true, forKey: Self.enabledKey)
        status = .on
        for record in existing { await backUp(record) }
    }

    func backUp(_ record: BackupRecord) async {
        guard isEnabled, let documents else { return }
        do {
            _ = try await documents.signIn()
            try await documents.write(collection: record.collection, id: record.id, json: record.json)
            backedUp += 1
            status = .backedUp(count: backedUp)
        } catch {
            status = .failed(Self.plain(error))
        }
    }

    static func plain(_ error: Error) -> String {
        let text = error.localizedDescription
        return text.isEmpty ? "no connection" : text
    }
}
