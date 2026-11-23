import SwiftUI

/// The leaf mark and "Ginkgo", as shown at the top of each tab. Both grow with the user's text size.
struct Wordmark: View {
    @ScaledMetric(relativeTo: .title2) private var markSize: CGFloat = 24

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image("GinkgoMark")
                .resizable()
                .scaledToFit()
                .frame(width: markSize, height: markSize)
                .accessibilityHidden(true)
            Text("Ginkgo")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Palette.brand)
                .accessibilityIdentifier("appTitle")
        }
    }
}
