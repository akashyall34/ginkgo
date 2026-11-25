import SwiftUI

/// Named colors, defined once in the asset catalog with light and dark variants.
/// Use these everywhere; never write a color value in a view.
enum Palette {
    static let brand = Color("Brand")
    static let verified = Color("Verified")
    static let fails = Color("Fails")
    /// Panels in the 3D transform: salvaged wood, and old panels the plan leaves out.
    static let wood = UIColor(red: 0.78, green: 0.62, blue: 0.43, alpha: 1)
    static let unusedPanel = UIColor(white: 0.62, alpha: 1)
    static let background = Color("LaunchBackground")
    static let onBrand = Color("LaunchBackground")
    /// Secondary text (captions, details). Darker than the system grey so it meets 4.5:1 on the cream background.
    static let secondaryText = Color("SecondaryText")

    /// Every named color, so tests can check each one exists and is readable.
    static let allNames = ["Brand", "Verified", "Fails", "LaunchBackground", "SecondaryText"]
    /// Colors used for text or icons on the background, which must meet contrast rules.
    static let foregroundNames = ["Brand", "Verified", "Fails", "SecondaryText"]
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Follow System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Spacing on a 4-point grid. Use these instead of literal numbers.
enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

/// Minimum tap target from Apple's Human Interface Guidelines.
enum TapTarget {
    static let minimum: CGFloat = 44
}

/// Contrast between two colors, as defined by WCAG 2.x.
enum Contrast {
    static func ratio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func luminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &alpha)
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}

/// A list section's title in the app's secondary text color: the system's default header gray falls just short of
/// the contrast audit on the light background.
struct SectionTitle: View {
    let text: String
    nonisolated init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).foregroundStyle(Palette.secondaryText)
    }
}

extension Section where Parent == SectionTitle, Content: View, Footer == EmptyView {
    init(titled title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { SectionTitle(title) })
    }
}
