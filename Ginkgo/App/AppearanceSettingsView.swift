import SwiftUI

/// Light, dark or follow the iPhone: chosen from Home's gear button and remembered.
struct AppearanceSettingsView: View {
    @AppStorage("appearancePreference") private var appearancePreferenceRawValue = AppearancePreference.system.rawValue
    @Environment(\.dismiss) private var dismiss

    private var appearancePreference: AppearancePreference {
        AppearancePreference(rawValue: appearancePreferenceRawValue) ?? .system
    }

    var body: some View {
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
                    Button("Done") { dismiss() }
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
}
