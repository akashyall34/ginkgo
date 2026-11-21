import SwiftUI

/// The first screen: what Ginkgo does, and the way in.
struct HomeView: View {
    var body: some View {
        NavigationStack {
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
                NavigationLink {
                    ScanView(source: FrameSources.makeDefault())
                } label: {
                    Label("Scan furniture", systemImage: "viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand)
                .accessibilityIdentifier("scanButton")
            }
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
        }
    }
}

#Preview("Light") { HomeView() }
#Preview("Dark") { HomeView().preferredColorScheme(.dark) }
