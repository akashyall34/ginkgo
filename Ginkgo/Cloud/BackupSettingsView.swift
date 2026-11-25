import SwiftUI

/// The backup switch in Settings: off by default, and it says exactly what leaves the phone.
struct BackupSettingsView: View {
    let backup: CloudBackup

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Backup").font(.headline)
            Toggle(isOn: Binding(
                get: { backup.isEnabled },
                set: { on in
                    Task {
                        let existing = on ? ScanStore.standard().list().map(BackupRecord.piece) : []
                        await backup.setEnabled(on, existing: existing)
                    }
                }
            )) {
                Text("Back up measurements and plans")
            }
            .disabled(!backup.isAvailable)
            .frame(minHeight: TapTarget.minimum)
            .accessibilityIdentifier("backupToggle")
            Text(backup.statusLine)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("backupStatus")
            Text("Only sizes and plans are sent, to Google Firebase. Photos and depth maps stay on this iPhone.")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
