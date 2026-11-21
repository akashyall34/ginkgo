import Foundation
@testable import GinkgoCore

/// Loads the shared sample data in the repo's `examples/` folder, found relative to this file.
enum Fixtures {
    /// Tests/GinkgoCoreTests/Fixtures.swift → up five levels is the repo root.
    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }()

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: repoRoot.appendingPathComponent("examples").appendingPathComponent(name))
    }

    static func inventory() throws -> Inventory {
        try JSONDecoder().decode(Inventory.self, from: data("inventory.json"))
    }

    static func planBench() throws -> Plan {
        try JSONDecoder().decode(Plan.self, from: data("plan_bench.json"))
    }

    /// The sample plan as the AI would submit it: no positions, rotations or overall size.
    static func benchDraft() throws -> PlanDraft {
        let plan = try planBench()
        let parts = plan.newParts.map { part in
            DraftPart(heightMm: part.heightMm, name: part.name, role: part.role, sourcePartID: part.sourcePartID,
                      spanMm: part.spanMm, widthMm: part.widthMm)
        }
        return PlanDraft(hardware: plan.hardware, newParts: parts, steps: plan.steps, template: plan.template)
    }
}
