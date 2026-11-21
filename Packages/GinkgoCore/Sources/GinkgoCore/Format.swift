import Foundation

/// Number formatting for messages people read.
public enum Format {
    /// A length in mm, rounded to 0.1: whole numbers print without decimals ("52"), others with one ("0.4").
    public static func mm(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10 + 0.0   // "+ 0.0" turns -0.0 into 0.0
        return rounded == rounded.rounded() ? String(format: "%.0f", rounded) : String(format: "%.1f", rounded)
    }
}
