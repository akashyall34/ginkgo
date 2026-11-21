import Foundation

/// How measurements are written on screen: centimeters with one decimal, plus inches,
/// since judges and many users think in inches.
enum MeasurementFormat {
    static func size(widthMeters: Float, heightMeters: Float) -> String {
        String(format: "%.1f × %.1f cm", widthMeters * 100, heightMeters * 100)
    }

    static func inches(widthMeters: Float, heightMeters: Float) -> String {
        String(format: "%.1f × %.1f in", widthMeters / 0.0254, heightMeters / 0.0254)
    }

    static func plusMinus(meters: Float) -> String {
        String(format: "± %.1f cm", meters * 100)
    }

    /// The same numbers in words, for VoiceOver.
    static func spoken(widthMeters: Float, heightMeters: Float, uncertaintyMeters: Float) -> String {
        String(format: "%.1f by %.1f centimeters, plus or minus %.1f",
               widthMeters * 100, heightMeters * 100, uncertaintyMeters * 100)
    }
}
