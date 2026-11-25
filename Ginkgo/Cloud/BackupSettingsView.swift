import SwiftUI

/// The backup switch in Settings: off by default, and it says exactly what leaves the phone.
struct BackupSettingsView: View {
    let backup: CloudBackup
    var account = AccountModel.shared

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
            if backup.isEnabled && account.isAvailable { accountRow }
        }
        .task { await account.refresh() }
    }

    private var accountRow: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(account.line)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("accountLine")
            Button {
                Task { account.isSignedIn ? await account.signOut() : await account.signIn() }
            } label: {
                Label(account.isSignedIn ? "Sign out" : "Sign in with Google",
                      systemImage: account.isSignedIn ? "rectangle.portrait.and.arrow.right" : "person.crop.circle")
                    .frame(minHeight: TapTarget.minimum)
            }
            .disabled(account.state == .signingIn)
            .accessibilityIdentifier("accountButton")
        }
    }
}
