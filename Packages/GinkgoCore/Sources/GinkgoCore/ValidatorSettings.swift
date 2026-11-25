import Foundation

/// Validator limits that Remote Config can change without a new build, but only to make them stricter.
/// The built-in values are sourced (see `Packer.builtInMargin`, `Sag.limit`, `Sag.designLoadKg`); a remote value is
/// used only when it is at least the built-in value and at most `typoGuard` times it, so a console typo can never
/// loosen the checks, and an absurd one can't block every plan.
public struct ValidatorSettings: Equatable, Sendable {
    /// Remote Config keys.
    public enum Key: String, CaseIterable, Sendable {
        case marginMm = "validator_margin_mm"
        case sagSpanDivisor = "validator_sag_span_divisor"
        case seatLoadKg = "validator_seat_load_kg"
        case shelfLoadKg = "validator_shelf_load_kg"
    }

    /// A remote value more than this many times the built-in one is taken as a typo and ignored.
    public static let typoGuard = 4.0

    public var remote: [Key: Double]

    public init(remote: [Key: Double] = [:]) { self.remote = remote }

    /// The value the validator uses: the remote one when it's stricter and sane, otherwise the built-in one.
    public func value(_ key: Key, builtIn: Double) -> Double {
        guard let wanted = remote[key], wanted.isFinite, wanted >= builtIn, wanted <= builtIn * Self.typoGuard else {
            return builtIn
        }
        return wanted
    }

    /// Keys whose remote value was ignored, for the log.
    public func ignored(builtIns: [Key: Double]) -> [Key] {
        Key.allCases.filter { key in
            guard let wanted = remote[key], let builtIn = builtIns[key] else { return false }
            return value(key, builtIn: builtIn) != wanted
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stored = ValidatorSettings()

    /// What every validation uses. Set once Remote Config has been fetched; the built-in values until then.
    public static var current: ValidatorSettings {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
