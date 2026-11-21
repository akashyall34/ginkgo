import SwiftUI
import UIKit

struct MyItemsView: View {
    let store: ScanStore
    let onAppearanceSettings: () -> Void

    @State private var items: [SavedScanItem] = []
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            header

            Text("Previously Scanned")
                .font(.title2.bold())
                .foregroundStyle(Palette.brand)
                .accessibilityIdentifier("previouslyScannedTitle")

            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Palette.fails)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("savedScansError")
            }

            if items.isEmpty && loadError == nil {
                ContentUnavailableView(
                    "No saved scans yet",
                    systemImage: "tray",
                    description: Text("Completed LiDAR measurements are saved here on this device.")
                )
            } else {
                ForEach(items) { item in
                    scanCard(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.bottom, 112)
        .onAppear(perform: loadItems)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 7) {
                Image("GinkgoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("Ginkgo")
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(Palette.brand)
            }

            Spacer()
            Button(action: onAppearanceSettings) {
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
    }

    private func scanCard(_ item: SavedScanItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text(item.scan.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.background.opacity(0.96), in: Capsule())
                        .padding(Spacing.medium)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityLabel("Previously scanned furniture")

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Furniture scan")
                        .font(.headline)
                    Text(item.scan.date.formatted(date: .long, time: .omitted))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xSmall) {
                    Text(MeasurementFormat.size(
                        widthMeters: item.scan.result.width,
                        heightMeters: item.scan.result.height
                    ))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Palette.brand)

                    Text(MeasurementFormat.plusMinus(meters: item.scan.result.uncertainty))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("savedScan-\(item.id.uuidString)")
    }

    private func loadItems() {
        var loaded: [SavedScanItem] = []
        var failures: [String] = []

        for scan in store.list() {
            do {
                let preview = try store.preview(scan.id)
                guard let image = UIImage(data: preview.photo) else {
                    throw ScanStoreError.unreadable("The saved photo isn't a supported image.")
                }
                loaded.append(SavedScanItem(scan: preview.scan, image: image))
            } catch {
                failures.append(errorMessage(for: error))
            }
        }

        items = loaded
        if let firstFailure = failures.first {
            let remainingCount = failures.count - 1
            loadError = remainingCount == 0
                ? firstFailure
                : "\(firstFailure) \(remainingCount) other saved item(s) could not be loaded."
        } else {
            loadError = nil
        }
    }

    private func errorMessage(for error: Error) -> String {
        guard let error = error as? ScanStoreError else {
            return "A saved scan couldn't be loaded."
        }
        switch error {
        case .notFound:
            return "A saved scan couldn't be found."
        case .unreadable(let reason):
            return "A saved scan couldn't be read: \(reason)"
        }
    }
}

private struct SavedScanItem: Identifiable {
    let scan: SavedScan
    let image: UIImage

    var id: UUID { scan.id }
}
