import SwiftUI

/// The first screen. A placeholder for the Scan flow, built on the design system.
struct HomeView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(.largeTitle))
                .imageScale(.large)
                .foregroundStyle(Palette.brand)
                .accessibilityHidden(true)
            Text("Ginkgo")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("appTitle")
            Text("Measure it with your phone. Get a plan that fits.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("tagline")
            Spacer()
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

#Preview("Light") { HomeView() }
#Preview("Dark") { HomeView().preferredColorScheme(.dark) }
