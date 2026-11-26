import Foundation
import GinkgoCore

/// The parts list for the plan, and how it was made.
struct PartsResult {
    let inventory: Inventory
    /// "Check this" notes for the Confirm screen.
    let flags: [PartFlag]
    /// False when Gemini couldn't be reached and the parts were estimated from the measured box.
    let fromGemini: Bool
}

/// Parts: Gemini reads the photo with the measured size; Vivek's PartsReader turns its answer into a
/// parts list. Without a photo or a connection it falls back to the box estimate, and says so.
enum PartsStep {
    static let offlineMessage = "Gemini couldn't read the photo (no connection?), so the parts are estimated from "
        + "the measured size. Check each one."

    /// The measured size the way PartsReader expects it, in mm: x across the front (the length),
    /// y the height, z front to back (the width).
    static func measured(_ box: FittedBox) -> Vector3 {
        Vector3(x: (Double(box.length) * 1000).rounded(), y: (Double(box.height) * 1000).rounded(),
                z: (Double(box.width) * 1000).rounded())
    }

    /// The text sent with the photo: Vivek's prompt plus the measured size.
    static func prompt(for size: Vector3) -> String {
        PartsReader.prompt + "\n" + String(format: "Measured size: %.0f mm wide, %.0f mm tall, %.0f mm deep.",
                                           size.x, size.y, size.z)
    }

    /// `ask` sends the prompt and photo to Gemini and returns its JSON text.
    @MainActor
    static func read(photo: Data?, box: FittedBox, scanID: String,
                     ask: (String, Data) async throws -> String) async -> PartsResult {
        let size = measured(box)
        guard let photo else { return estimate(box, scanID: scanID) }
        do {
            let reading = try PartsReader.parse(try await ask(prompt(for: size), photo))
            let result = PartsReader.inventory(from: reading, measured: size, scanID: scanID)
            guard !result.inventory.parts.isEmpty else { return estimate(box, scanID: scanID) }
            return PartsResult(inventory: result.inventory, flags: result.flags, fromGemini: true)
        } catch {
            return estimate(box, scanID: scanID)
        }
    }

    static let rereadFailed = "Gemini still couldn't read the photo, so the estimate and your changes stay."

    /// "Read the parts from the photo": offered for parts estimated offline when there's a photo and the network is back.
    static func canReread(_ result: PartsResult, hasPhoto: Bool, online: Bool) -> Bool {
        !result.fromGemini && hasPhoto && online
    }

    /// Gemini's reading replaces the estimate only when it actually read the photo (its parts are new, so they need
    /// confirming again). Otherwise the estimate, with the person's changes, stays, and says so.
    static func reread(edited: Inventory, flags: [PartFlag], attempt: PartsResult) -> PartsResult {
        if attempt.fromGemini { return attempt }
        let note = PartFlag(message: rereadFailed, partID: "all")
        return PartsResult(inventory: edited, flags: flags.contains(note) ? flags : flags + [note], fromGemini: false)
    }

    static func estimate(_ box: FittedBox, scanID: String) -> PartsResult {
        PartsResult(inventory: LivePlan.inventory(from: box, scanID: scanID),
                    flags: [PartFlag(message: offlineMessage, partID: "all")], fromGemini: false)
    }

    /// "60.0 × 35.0 cm, 18 mm thick (estimated)": an unmeasured thickness says so.
    static func sizeLine(_ part: Part) -> String {
        String(format: "%.1f × %.1f cm, %.0f mm thick", part.widthMm / 10, part.heightMm / 10, part.thicknessMm)
            + (part.thicknessIsMeasured ? "" : " (estimated)")
    }

    /// For a guessed wood material: what it's rated as until confirmed, as a tap-to-confirm line. Nil once confirmed,
    /// and for materials a guess can't make weaker.
    static func materialNote(_ part: Part) -> String? {
        guard !part.materialIsConfirmed, part.ratedForStrength.material != part.material else { return nil }
        let name = MaterialCatalog.info(part.material).displayName
        return "Guessed. Rated as particleboard until you confirm. Tap if it's \(name)."
    }

    /// For solid wood whose wood lines haven't been checked: the warning shown under the grain picker.
    static func grainNote(_ part: Part) -> String? {
        guard part.material == .solidWood, part.grain == nil else { return nil }
        return "Not checked: rated as across the grain, which is much weaker. Look at the wood lines and pick their direction."
    }

    /// The inventory with one part's grain set.
    static func setting(grain: Grain, of partID: String, in inventory: Inventory) -> Inventory {
        inventory.with(parts: inventory.parts.map { $0.id == partID ? $0.with(grain: grain) : $0 })
    }

    /// The inventory with one part's material changed (picked on Confirm).
    static func setting(_ material: Material, of partID: String, in inventory: Inventory) -> Inventory {
        inventory.with(parts: inventory.parts.map {
            $0.id == partID ? $0.with(material: material, materialSource: .confirmed) : $0
        })
    }
}
