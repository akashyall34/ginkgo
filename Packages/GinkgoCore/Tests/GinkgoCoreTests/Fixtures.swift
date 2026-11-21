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
}
