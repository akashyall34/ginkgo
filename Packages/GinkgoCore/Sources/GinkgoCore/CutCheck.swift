import Foundation

/// A cut piece as scanned: its two face sizes, mm. Either way round.
public struct ScannedPiece: Sendable, Equatable {
    public var name: String
    public var widthMm: Double
    public var heightMm: Double

    public init(name: String, widthMm: Double, heightMm: Double) {
        self.name = name
        self.widthMm = widthMm
        self.heightMm = heightMm
    }
}

/// What to do with a cut piece.
public enum CutVerdict: Sendable, Equatable {
    /// Within tolerance of the plan.
    case good
    /// Too long: trim this much off each face size (0 means that size is fine).
    case trim(widthMm: Double, heightMm: Double)
    /// Shorter than planned, but the plan with the real size still passes every check.
    case useAsIs(shortByMm: Double)
    /// Shorter than planned, and the plan no longer passes: the reason, in the validator's words.
    case recut(reason: String)
}

public struct CutCheckResult: Sendable, Equatable {
    public var piece: String
    public var verdict: CutVerdict
    /// What the person reads.
    public var message: String
}

/// After sawing: each piece's scan against its planned size. Long pieces get a trim; short ones are re-checked by
/// the validator with their real size, so a piece is only used if the build is still proven. Supports must match
/// each other, or the build wobbles. Pure and deterministic.
public enum CutCheck {
    /// Ginkgo's assembly tolerance: pieces within this of the plan are good, mm. A design choice, not a measurement.
    public static let toleranceMm = 2.0

    public static func check(_ scanned: ScannedPiece, plan: Plan, inventory: Inventory) -> CutCheckResult {
        guard let planned = plan.newParts.first(where: { $0.name == scanned.name }) else {
            return CutCheckResult(piece: scanned.name, verdict: .recut(reason: "\(scanned.name) isn't in this plan."),
                                  message: "\(scanned.name) isn't in this plan.")
        }
        // Compare long side with long side, so the piece can be scanned either way round.
        let (longPlan, shortPlan) = ordered(planned.widthMm, planned.heightMm)
        let (longScan, shortScan) = ordered(scanned.widthMm, scanned.heightMm)
        let longDiff = longScan - longPlan, shortDiff = shortScan - shortPlan
        let allowance = toleranceMm

        if abs(longDiff) <= allowance && abs(shortDiff) <= allowance {
            return CutCheckResult(piece: planned.name, verdict: .good,
                                  message: "\(label(planned.name)): \(sizes(longScan, shortScan)), "
                                    + "within \(Format.mm(allowance)) mm. Good.")
        }
        if longDiff >= -allowance && shortDiff >= -allowance {
            // Too long only: trim back to the plan.
            let trimLong = longDiff > allowance ? longDiff : 0, trimShort = shortDiff > allowance ? shortDiff : 0
            let (trimWidth, trimHeight) = planned.widthMm >= planned.heightMm ? (trimLong, trimShort) : (trimShort, trimLong)
            return CutCheckResult(piece: planned.name, verdict: .trim(widthMm: trimWidth, heightMm: trimHeight),
                                  message: trimMessage(label(planned.name), width: trimWidth, height: trimHeight))
        }
        // Short somewhere: re-check the whole plan with the piece at its real size (long sides kept at the plan if long).
        let realLong = min(longScan, longPlan), realShort = min(shortScan, shortPlan)
        let (realWidth, realHeight) = planned.widthMm >= planned.heightMm ? (realLong, realShort) : (realShort, realLong)
        let resized = plan.with(newParts: plan.newParts.map {
            $0.name == planned.name ? $0.with(heightMm: realHeight, widthMm: realWidth) : $0
        })
        let validation = Validator.validate(plan: resized, inventory: inventory, limits: nil)
        let shortBy = max(longPlan - longScan, shortPlan - shortScan)
        if validation.passes {
            return CutCheckResult(piece: planned.name, verdict: .useAsIs(shortByMm: shortBy),
                                  message: "\(label(planned.name)): \(Format.mm(shortBy)) mm short, but the build still passes "
                                    + "every check at this size. Use it as is.")
        }
        let reason = validation.violations.map(\.message).joined(separator: " ")
        return CutCheckResult(piece: planned.name, verdict: .recut(reason: reason),
                              message: "\(label(planned.name)): \(Format.mm(shortBy)) mm short, and the build no longer passes. "
                                + "Cut it again from spare wood. \(reason)")
    }

    /// Supports that should match but differ by more than the tolerance: trim the taller ones to the shortest.
    /// Returns one instruction per support to trim, in plan order.
    public static func matchSupports(_ scanned: [ScannedPiece], plan: Plan) -> [String] {
        let supports = plan.newParts.filter { $0.role == .support }
        let heights: [(name: String, mm: Double)] = supports.compactMap { support in
            guard let piece = scanned.first(where: { $0.name == support.name }) else { return nil }
            return (support.name, ordered(piece.widthMm, piece.heightMm).long)
        }
        guard heights.count >= 2, let lowest = heights.map(\.mm).min() else { return [] }
        return heights.filter { $0.mm - lowest > toleranceMm }.map {
            "\(label($0.name)): trim \(Format.mm($0.mm - lowest)) mm off its long side to match the other supports, "
                + "or the build will wobble."
        }
    }

    /// "leg_right" → "Right leg", at the start of a message.
    static func label(_ name: String) -> String { Format.partName(name).capitalizedFirst }

    static func ordered(_ a: Double, _ b: Double) -> (long: Double, short: Double) { a >= b ? (a, b) : (b, a) }

    static func sizes(_ long: Double, _ short: Double) -> String { "\(Format.mm(long)) × \(Format.mm(short)) mm" }

    static func trimMessage(_ name: String, width: Double, height: Double) -> String {
        var parts: [String] = []
        if width > 0 { parts.append("\(Format.mm(width)) mm off its width") }
        if height > 0 { parts.append("\(Format.mm(height)) mm off its height") }
        return "\(name): too long. Trim \(parts.joined(separator: " and ")), then scan it again."
    }
}
