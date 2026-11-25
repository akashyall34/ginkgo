import SwiftUI

/// Light, dark or follow the iPhone: chosen from Home's gear button and remembered.
struct AppearanceSettingsView: View {
    @AppStorage("appearancePreference") private var appearancePreferenceRawValue = AppearancePreference.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    private var appearancePreference: AppearancePreference {
        AppearancePreference(rawValue: appearancePreferenceRawValue) ?? .system
    }

    /// Shown as a sheet with its own Done button; `pushed` shows it inside an existing navigation stack instead.
    var pushed = false

    var body: some View {
        if pushed {
            options.background(Palette.background)
        } else {
            NavigationStack {
                options.toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                        .accessibilityIdentifier("appearanceDone")
                    }
                }
            }
            // Half height normally; it can grow when large text needs the room.
            .presentationDetents([.medium, .large])
        }
    }

    private var options: some View {
        ScrollView {
            optionList
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Palette.brand)
    }

    private var optionList: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            // Three across normally; one per line at accessibility text sizes.
            let row = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Spacing.small))
                : AnyLayout(HStackLayout(spacing: Spacing.small))
            row {
                ForEach(AppearancePreference.allCases) { preference in
                    appearanceOption(preference)
                }
            }

            Text("Follow System matches your iPhone's appearance setting.")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            BackupSettingsView(backup: CloudBackup.shared)
        }
        .padding(Spacing.large)
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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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
}
