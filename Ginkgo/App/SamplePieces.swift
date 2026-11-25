import Foundation
import GinkgoCore

/// Ready-made pieces in My items, so a new person can try the whole flow before scanning anything. They're sample
/// data, not measurements: the props carry no measurement or material sources, so the validator treats their
/// thicknesses as estimates and their materials as guesses, exactly as it would an unchecked scan.
struct SamplePiece: Identifiable, Equatable {
    let id: String
    let name: String
    let inventory: Inventory

    /// "4 parts · biggest 60 × 40 cm".
    var summary: String {
        let count = inventory.parts.count
        let parts = count == 1 ? "1 part" : "\(count) parts"
        guard let biggest = inventory.parts.max(by: { $0.widthMm * $0.heightMm < $1.widthMm * $1.heightMm }) else {
            return parts
        }
        return parts + String(format: " · biggest %.0f × %.0f cm", biggest.widthMm / 10, biggest.heightMm / 10)
    }

    /// The sample nightstand, then the props, in the order a person would try them. Files that can't be read are
    /// left out rather than shown broken.
    /// Where a sample comes from: its id, its name on the card, and its file in the app.
    struct Source {
        let id: String
        let name: String
        let file: String
    }

    static let shipped = [Source(id: "nightstand", name: "Nightstand", file: "inventory"),
                          Source(id: "stool", name: "Stool", file: "stool"),
                          Source(id: "drawer-cart", name: "Drawer cart", file: "drawer_cart"),
                          Source(id: "box", name: "Box", file: "box")]

    static func all(bundle: Bundle = .main, files: [Source] = shipped) -> [SamplePiece] {
        files.compactMap { source in
            guard let url = bundle.url(forResource: source.file, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let inventory = try? JSONDecoder().decode(Inventory.self, from: data),
                  !inventory.parts.isEmpty else { return nil }
            return SamplePiece(id: source.id, name: source.name, inventory: inventory)
        }
    }
}
