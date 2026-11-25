import ImageIO
import SwiftUI
import UIKit

struct MyItemsView: View {
    let store: ScanStore
    let onAppearanceSettings: () -> Void

    @State private var items: [SavedScanItem] = []
    @State private var loadError: String?
    private let samples = SamplePiece.all()

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
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("savedScansError")
            }

            if items.isEmpty && loadError == nil {
                ContentUnavailableView(
                    "No saved scans yet",
                    systemImage: "tray",
                    description: Text("Your LiDAR measurements are saved here on this iPhone. "
                                      + "Until then, try one of the samples below.")
                )
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.large) {
                    ForEach(items) { item in
                        NavigationLink {
                            SavedScanDetailView(store: store, scan: item.scan, onDelete: {
                                items.removeAll { $0.id == item.id }
                            })
                        } label: {
                            scanCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !samples.isEmpty { sampleSection }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.bottom, 112)
        .task { await loadItems() }
    }

    private var header: some View {
        HStack {
            Wordmark()

            Spacer()
            NavigationLink { AppearanceSettingsView(pushed: true) } label: {
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

    /// Ready-made pieces to try the flow with; each opens what it can become, like a scan does.
    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Try a sample")
                .font(.title2.bold())
                .foregroundStyle(Palette.brand)
                .accessibilityAddTraits(.isHeader)
            Text("Sample data, not your scan: sizes and materials are examples, and Ginkgo checks them as unconfirmed.")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(samples) { sample in
                NavigationLink {
                    IdeasView(inventory: sample.inventory)
                } label: {
                    HStack(spacing: Spacing.medium) {
                        Image(systemName: "shippingbox")
                            .font(.title3)
                            .foregroundStyle(Palette.brand)
                            .frame(width: TapTarget.minimum, height: TapTarget.minimum)
                            .background(Palette.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text(sample.name).font(.headline).foregroundStyle(.primary)
                            Text(sample.summary)
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                            .accessibilityHidden(true)
                    }
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, minHeight: TapTarget.minimum, alignment: .leading)
                    .background(Palette.brand.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Sample data. Shows what it can become.")
                .accessibilityIdentifier("sample-\(sample.id)")
            }
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
                // The cropped-off part of a tall photo must not catch taps meant for the header above.
                .contentShape(Rectangle())
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

            SplitRow {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Furniture scan")
                        .font(.headline)
                    Text(item.scan.date.formatted(date: .long, time: .omitted))
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                }
            } trailing: {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(MeasurementFormat.size(
                        widthMeters: item.scan.result.width,
                        heightMeters: item.scan.result.height
                    ))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Palette.brand)

                    Text(MeasurementFormat.plusMinus(meters: item.scan.result.uncertainty))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("savedScan-\(item.id.uuidString)")
    }

    /// Reads the saved scans off the main thread and decodes small thumbnails, so opening My items stays
    /// instant however many scans are saved.
    private func loadItems() async {
        let store = store
        let (loaded, failures) = await Task.detached(priority: .userInitiated) { () -> ([SavedScanItem], [Error]) in
            var loaded: [SavedScanItem] = []
            var failures: [Error] = []
            for scan in store.list() {
                do {
                    let preview = try store.preview(scan.id)
                    guard let image = Self.thumbnail(from: preview.photo) else {
                        throw ScanStoreError.unreadable("The saved photo isn't a supported image.")
                    }
                    loaded.append(SavedScanItem(scan: preview.scan, image: image))
                } catch {
                    failures.append(error)
                }
            }
            return (loaded, failures)
        }.value

        items = loaded
        if let firstFailure = failures.first.map(errorMessage) {
            let remainingCount = failures.count - 1
            loadError = remainingCount == 0
                ? firstFailure
                : "\(firstFailure) \(remainingCount) other saved item(s) could not be loaded."
        } else {
            loadError = nil
        }
    }

    /// A small image for a card, decoded straight from the saved photo without loading it at full size.
    nonisolated private static func thumbnail(from data: Data, maxPixels: Int = 300) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxPixels]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
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
