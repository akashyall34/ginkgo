import Foundation

extension Inventory {
    /// The parts by id. If an id appears twice, the first one wins, which is the one the packer reads.
    var partsByID: [String: Part] {
        Dictionary(parts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
