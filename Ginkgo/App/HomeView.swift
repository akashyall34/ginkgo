import SwiftUI

/// The first screen: what Ginkgo does, and the way in.
struct HomeView: View {
    @State private var selectedTab: Int

    /// `initialTab`: 0 Home, 1 My items, 2 Guide (tests open a tab directly).
    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
        let seen = UserDefaults.standard.bool(forKey: FirstRunGuide.seenKey)
        _isFirstRunPresented = State(initialValue: FirstRunGuide.shouldShow(seen: seen, initialTab: initialTab))
    }
    @State private var isFirstRunPresented: Bool
    @AppStorage(FirstRunGuide.seenKey) private var hasSeenFirstRun = false
    /// The step number badge grows with the text inside it.
    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 32
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isAppearanceSettingsPresented = false
    @State private var isDemoPresented = false
    @AppStorage("appearancePreference") private var appearancePreferenceRawValue = AppearancePreference.system.rawValue

    private var appearancePreference: AppearancePreference {
        AppearancePreference(rawValue: appearancePreferenceRawValue) ?? .system
    }

    var body: some View {
        // The system tab bar: Liquid Glass on iOS 26+, scales with the text size, keeps content clear of it.
        TabView(selection: $selectedTab) {
            tab { homeContent }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            tab {
                MyItemsView(store: ScanStore.standard(), onAppearanceSettings: { isAppearanceSettingsPresented = true })
            }
            .tabItem { Label("My items", systemImage: "tray.full") }
            .tag(1)
            tab { GuideView(onAppearanceSettings: { isAppearanceSettingsPresented = true }) }
                .tabItem { Label("Guide", systemImage: "book") }
                .tag(2)
        }
        .tint(Palette.brand)
        .preferredColorScheme(appearancePreference.colorScheme)
        .sheet(isPresented: $isAppearanceSettingsPresented) {
            AppearanceSettingsView()
        }
        .fullScreenCover(isPresented: $isFirstRunPresented) {
            FirstRunGuideView(
                onFinish: { finishFirstRun() },
                onTrySample: {
                    selectedTab = 1
                    finishFirstRun()
                }
            )
        }
        .fullScreenCover(isPresented: $isDemoPresented) {
            DemoView(onClose: { isDemoPresented = false })
        }
    }

    private func finishFirstRun() {
        hasSeenFirstRun = true
        isFirstRunPresented = false
    }

    /// One tab: its own navigation, scrolling content on the app background.
    private func tab(@ViewBuilder _ content: () -> some View) -> some View {
        NavigationStack {
            ScrollView {
                content()
                    .padding(.horizontal, Spacing.large)
                    .padding(.bottom, Spacing.large)
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            heroTitle
                .padding(.top, Spacing.medium)

            heroPhoto
                .padding(.top, Spacing.large)

            NavigationLink {
                ScanView(source: FrameSources.makeDefault())
            } label: {
                HStack(spacing: Spacing.small) {
                    Image(systemName: "camera")
                        .font(.title3.weight(.semibold))
                        .accessibilityHidden(true)
                    Text("Snap furniture")
                        .font(.title3.weight(.semibold))
                }
                .foregroundStyle(Palette.onBrand)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 80)
                .background(Palette.brand)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("snapFurniture")
            .padding(.top, Spacing.medium)

            secondaryActions
                .padding(.top, Spacing.small)

            impactSection
                .padding(.top, Spacing.xLarge)
        }
    }

    /// The worked example and the judge walkthrough, one tap from Home.
    private var secondaryActions: some View {
        HStack(spacing: Spacing.small) {
            NavigationLink {
                ExampleProofView()
            } label: {
                Label("See an example", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
            }
            .accessibilityIdentifier("exampleButton")
            Button {
                isDemoPresented = true
            } label: {
                Label("Demo", systemImage: "play.circle")
                    .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
            }
            .accessibilityIdentifier("demoButton")
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Palette.brand)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Wordmark()

            Spacer()
            appearanceSettingsButton
        }
        .padding(.top, 10)
    }

    private var appearanceSettingsButton: some View {
        Button {
            isAppearanceSettingsPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.title3)
                .foregroundStyle(Palette.brand)
                .frame(width: TapTarget.minimum, height: TapTarget.minimum)
                .background(Palette.brand.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Appearance settings")
        .accessibilityIdentifier("appearanceSettings")
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("A second life starts\nwith a snapshot.")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(Palette.brand)

            Text("Snap your furniture. Find the best way to repurpose it.")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("tagline")
        }
    }

    private var heroPhoto: some View {
        ZStack(alignment: .topLeading) {
            roomScene
                .frame(height: 224)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text("A fresh start. One snap.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Palette.background.opacity(0.96))
                .clipShape(Capsule())
                .padding(.top, 20)
                .padding(.leading, 20)
        }
    }

    private var roomScene: some View {
        Image("PreLovedArmchair")
            .resizable()
            .scaledToFill()
            .accessibilityLabel("Pre-loved wooden armchair")
    }

    private var impactSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Less landfill. More possibility.")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Palette.brand)

            // Side by side normally; stacked at accessibility text sizes so nothing is squeezed.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.medium))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.small))
            layout {
                step(number: "01", title: "Snap it", detail: "Take a clear photo")
                step(number: "02", title: "Find a way", detail: "Explore your options")
                step(number: "03", title: "Pass it on", detail: "Give it a new life")
            }
        }
    }

    private func step(number: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(number)
                .font(.caption2.bold())
                .foregroundStyle(Palette.brand)
                .frame(minWidth: badgeSize, minHeight: badgeSize)
                .background(Palette.brand.opacity(0.14))
                .clipShape(Capsule())

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") { HomeView() }
#Preview("Dark") { HomeView().preferredColorScheme(.dark) }
