import SwiftUI

/// The first screen: what Ginkgo does, and the way in.
struct HomeView: View {
    @State private var selectedTab = 0
    @State private var isAppearanceSettingsPresented = false
    @AppStorage("appearancePreference") private var appearancePreferenceRawValue = AppearancePreference.system.rawValue

    private var appearancePreference: AppearancePreference {
        AppearancePreference(rawValue: appearancePreferenceRawValue) ?? .system
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    Group {
                        if selectedTab == 2 {
                            GuideView(onAppearanceSettings: {
                                isAppearanceSettingsPresented = true
                            })
                        } else {
                            homeContent
                        }
                    }
                    .padding(.horizontal, Spacing.large)
                }

                bottomNavigation
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(appearancePreference.colorScheme)
        .sheet(isPresented: $isAppearanceSettingsPresented) {
            appearanceSettings
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
                .frame(height: 80)
                .background(Palette.brand)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("snapFurniture")
            .padding(.top, Spacing.medium)

            impactSection
                .padding(.top, 36)
                .padding(.bottom, 112)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 7) {
                Image("GinkgoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("Ginkgo")
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(Palette.brand)
                    .accessibilityIdentifier("appTitle")
            }

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

    private var appearanceSettings: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.large) {
                HStack(spacing: Spacing.small) {
                    ForEach(AppearancePreference.allCases) { preference in
                        appearanceOption(preference)
                    }
                }

                Text("Follow System matches your iPhone's appearance setting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(Spacing.large)
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isAppearanceSettingsPresented = false
                    }
                    .accessibilityIdentifier("appearanceDone")
                }
            }
        }
        .presentationDetents([.medium])
        .tint(Palette.brand)
    }

    private func appearanceOption(_ preference: AppearancePreference) -> some View {
        let isSelected = appearancePreference == preference
        return Button {
            appearancePreferenceRawValue = preference.rawValue
        } label: {
            VStack(spacing: Spacing.small) {
                Image(systemName: preference.symbol)
                    .font(.title3)
                Text(preference.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Palette.brand)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(
                isSelected ? Palette.brand.opacity(0.16) : Palette.background.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? Palette.brand : Palette.brand.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preference.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("appearance-\(preference.rawValue)")
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("A second life starts\nwith a snapshot.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Palette.brand)

            Text("Snap your furniture. Find the best way\nto repurpose it.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
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
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Palette.brand)

            HStack(alignment: .top, spacing: 8) {
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
                .frame(width: 32, height: 32)
                .background(Palette.brand.opacity(0.14))
                .clipShape(Capsule())

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottomNavigation: some View {
        HStack {
            navButton(index: 0, icon: "house", title: "Home")
            navButton(index: 1, icon: "tray.full", title: "My items")
            navButton(index: 2, icon: "book", title: "Guide")
        }
        .padding(8)
        .background {
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular, in: Capsule())
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(Palette.brand.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }

    private func navButton(index: Int, icon: String, title: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 6) {
                Image(systemName: selectedTab == index ? "\(icon).fill" : icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background {
                if selectedTab == index {
                    Capsule()
                        .fill(Palette.brand.opacity(0.12))
                        .padding(2)
                }
            }
        }
        .foregroundStyle(selectedTab == index ? Palette.brand : Color.secondary)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
}

#Preview("Light") { HomeView() }
#Preview("Dark") { HomeView().preferredColorScheme(.dark) }
