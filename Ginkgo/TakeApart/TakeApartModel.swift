import Foundation
import GinkgoCore
import Observation

/// Step 2: how to take the piece apart. Gemini reads the photo (it needs the image, so it runs in the cloud); with no
/// photo or no network, Ginkgo's template writes the guide. Either way, code checks the steps against the parts list.
@MainActor
@Observable
final class TakeApartModel {
    private(set) var guide: TakeApartGuide?
    /// Steps the person has ticked off.
    private(set) var done: Set<Int> = []
    /// What the routing log records about this reading.
    private(set) var entry: RoutingEntry?
    let inventory: Inventory
    let photo: Data?

    static let unreachable = "Gemini couldn't read the photo (no connection?), so this is Ginkgo's standard order."

    init(inventory: Inventory, photo: Data?) {
        self.inventory = inventory
        self.photo = photo
    }

    var isLoading: Bool { guide == nil }

    var sourceLine: String {
        switch guide?.source {
        case .gemini: return "Read by Gemini from your photo, checked against your parts"
        case .template, nil: return "Ginkgo's standard order for these parts"
        }
    }

    var progress: String {
        let total = guide?.steps.count ?? 0
        return "\(done.count) of \(total) done"
    }

    func toggle(_ number: Int) {
        if done.contains(number) { done.remove(number) } else { done.insert(number) }
    }

    /// `ask` sends the prompt and photo to Gemini and returns its JSON text.
    func load(online: Bool, modelName: String, date: Date = Date(),
              ask: (String, Data) async throws -> String) async {
        let route = HybridRouter.route(.readPhoto, RouteConditions(deviceModelAvailable: false, online: online))
        guard route.venue == .cloud, let photo else {
            guide = TakeApart.guide(nil, inventory: inventory)
            entry = RoutingEntry(task: .readPhoto, venue: .code, reason: .offlinePhotoTemplate, model: "template",
                                 durationMs: 0, verdict: .notRun, date: date)
            return
        }
        let start = ContinuousClock.now
        let reading = try? TakeApart.parse(try await ask(TakeApart.prompt(for: inventory), photo))
        var made = TakeApart.guide(reading, inventory: inventory)
        if reading == nil { made.notes.insert(Self.unreachable, at: 0) }
        guide = made
        let elapsed = ContinuousClock.now - start
        entry = RoutingEntry(task: .readPhoto, venue: .cloud, reason: route.reason,
                             model: made.source == .gemini ? modelName : "template",
                             durationMs: Int(elapsed.components.seconds * 1000
                                             + elapsed.components.attoseconds / 1_000_000_000_000_000),
                             verdict: made.source == .gemini ? .passed : .failed, date: date)
    }
}
