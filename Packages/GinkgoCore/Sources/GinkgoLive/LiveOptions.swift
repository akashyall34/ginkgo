import Foundation
import GinkgoCore

/// The command-line options shared by every ginkgo-live command.
struct LiveOptions {
    var inventory = "examples/inventory.json"
    var request = Prompts.defaultRequest
    var limits: SizeLimits?
    var maxTurns = 6
    var model = "gemini-3.8-flash"
    var timeout = 25
    var record: String?
    var thinking = true
    var photo: String?
    /// The tape or LiDAR size in mm: x = width, y = height, z = depth.
    var measured: Vector3?
    var runs = 2
    var withDimensions = false
    var also: [String] = []
    var out = "build/eval.md"

    static let valued: Set<String> = [
        "--inventory", "--request", "--max-width", "--max-height", "--max-depth", "--max-turns", "--model", "--timeout", "--record",
        "--photo", "--width", "--height", "--depth", "--limits", "--runs", "--also", "--out",
    ]
    static let flags: Set<String> = ["--no-thinking", "--with-dimensions"]

    struct Problem: Error, CustomStringConvertible {
        var description: String
    }

    init(_ words: [String]) throws {
        var values: [String: String] = [:]
        var switches: Set<String> = []
        var index = 0
        while index < words.count {
            let word = words[index]
            if Self.flags.contains(word) {
                switches.insert(word)
                index += 1
                continue
            }
            guard Self.valued.contains(word) else { throw Problem(description: "unknown option \(word)") }
            guard index + 1 < words.count else { throw Problem(description: "\(word) needs a value") }
            values[word] = words[index + 1]
            index += 2
        }
        thinking = !switches.contains("--no-thinking")
        withDimensions = switches.contains("--with-dimensions")
        try read(values)
    }

    private mutating func read(_ values: [String: String]) throws {
        inventory = values["--inventory"] ?? inventory
        request = values["--request"] ?? request
        model = values["--model"] ?? model
        record = values["--record"]
        photo = values["--photo"]
        out = values["--out"] ?? out
        also = values["--also"].map { $0.split(separator: ",").map(String.init) } ?? []
        maxTurns = try Self.whole(values["--max-turns"], "--max-turns") ?? maxTurns
        timeout = try Self.whole(values["--timeout"], "--timeout") ?? timeout
        runs = try Self.whole(values["--runs"], "--runs") ?? runs
        let width = try Self.millimetres(values["--max-width"], "--max-width")
        let height = try Self.millimetres(values["--max-height"], "--max-height")
        let depth = try Self.millimetres(values["--max-depth"], "--max-depth")
        if width != nil || height != nil || depth != nil {
            limits = SizeLimits(maxDepthMm: depth, maxHeightMm: height, maxWidthMm: width)
        }
        if let text = values["--limits"] {
            guard let parsed = SizeLimitsParser.parse(text) else { throw Problem(description: "no size limit found in \"\(text)\"") }
            limits = parsed
        }
        let size = try ["--width", "--height", "--depth"].map { try Self.millimetres(values[$0], $0) }
        if let x = size[0], let y = size[1], let z = size[2] { measured = Vector3(x: x, y: y, z: z) }
    }

    static func whole(_ text: String?, _ name: String) throws -> Int? {
        guard let text else { return nil }
        guard let value = Int(text), value > 0 else { throw Problem(description: "\(name) must be a whole number above 0") }
        return value
    }

    static func millimetres(_ text: String?, _ name: String) throws -> Double? {
        guard let text else { return nil }
        guard let value = Double(text), value > 0, value.isFinite else { throw Problem(description: "\(name) must be a size in mm") }
        return value
    }

    func requirePhoto() throws -> (path: String, measured: Vector3) {
        guard let photo, let measured else {
            throw Problem(description: "this needs --photo PATH and the measured --width, --height and --depth in mm")
        }
        return (photo, measured)
    }

    func loadInventory(_ path: String? = nil) throws -> Inventory {
        try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: URL(fileURLWithPath: path ?? inventory)))
    }
}
