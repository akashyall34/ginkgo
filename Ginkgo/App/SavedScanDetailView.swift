import SwiftUI

/// One saved scan: its photo, the measured size with its ±, and a way to delete it.
struct SavedScanDetailView: View {
    let store: ScanStore
    let scan: SavedScan
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage?
    @State private var confirmDelete = false
    @State private var deleteFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Group {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFit()
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityLabel("Photo of the scanned furniture")

                Text(MeasurementFormat.size(widthMeters: scan.result.width, heightMeters: scan.result.height))
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(Palette.brand)
                    .accessibilityIdentifier("savedScanSize")
                Text(MeasurementFormat.plusMinus(meters: scan.result.uncertainty))
                    .font(.subheadline).foregroundStyle(Palette.secondaryText)
                Text(scan.date.formatted(date: .long, time: .shortened))
                    .font(.footnote).foregroundStyle(Palette.secondaryText)

                if deleteFailed {
                    Text("This scan couldn't be deleted. Try again.").font(.footnote).foregroundStyle(Palette.fails)
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete scan", systemImage: "trash").frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("deleteScan")
            }
            .padding(Spacing.large)
        }
        .background(Palette.background)
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("Delete this scan?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                do {
                    try store.delete(scan.id)
                    onDelete()
                    dismiss()
                } catch {
                    deleteFailed = true
                }
            }
        }
        .task {
            let store = store, id = scan.id
            photo = await Task.detached { (try? store.preview(id)).flatMap { UIImage(data: $0.photo) } }.value
        }
    }
}
