import Foundation
import GinkgoCore

/// A real Gemini planning run, recorded on the sample furniture (examples/demo_trace.json): it fails checks,
/// repairs, and is accepted. Demo mode replays it when there's no connection; it's always labeled as recorded.
struct RecordedRun: Decodable {
    let model: String
    let outcome: String
    let seconds: Double
    let trace: [AgentStep]
    let plan: Plan

    static let label = "Recorded agent run · sample data"

    static func load(bundle: Bundle = .main) -> RecordedRun? {
        guard let url = bundle.url(forResource: "demo_trace", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RecordedRun.self, from: data)
    }

    /// "gemini-3.8-flash · accepted in 15.1 s"
    var detail: String { String(format: "%@ · %@ in %.1f s", model, outcome, seconds) }

    /// The recorded plan checked again by today's validator on the sample parts, so the proof is current.
    func proof(inventory: Inventory) -> ProofModel {
        ProofModel(plan: plan, result: Validator.validate(plan: plan, inventory: inventory, limits: nil), inventory: inventory)
    }
}
