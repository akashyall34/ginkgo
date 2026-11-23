import GinkgoCore
import SwiftUI

/// Parts and Confirm: Gemini lists the parts from the photo; the person checks them, picks each
/// part's material, and makes the plan. The confirmed list, not the AI's guess, is what gets planned.
struct PartsView: View {
    let box: FittedBox
    let photo: Data?
    @State private var scanID = UUID().uuidString
    @State private var result: PartsResult?
    @State private var inventory: Inventory?
    @State private var markingHolesOf: String?

    /// Every material the validator knows. Only solid wood and plywood get cut; the rest are reused whole.
    private struct MarkedPart: Identifiable { let id: String }
    private static let placeholder = Part(damaged: false, heightMm: 1, id: "", keepOuts: [], material: .solidWood,
                                          thicknessMm: 18, type: .top, widthMm: 1)

    static let materials: [(GinkgoCore.Material, String)] = [(.solidWood, "Solid wood"), (.plywood, "Plywood"),
                                                  (.particleboardMDF, "Particleboard / MDF"),
                                                  (.plastic, "Plastic"), (.cardboard, "Cardboard")]

    var body: some View {
        Group {
            if let result, let inventory {
                confirm(result, inventory)
            } else {
                ProgressView("Reading the parts from the photo…")
                    .accessibilityIdentifier("partsLoading")
            }
        }
        .sheet(item: Binding(get: { markingHolesOf.map(MarkedPart.init) }, set: { markingHolesOf = $0?.id })) { marked in
            ScrewHolesView(part: Binding(
                get: { inventory?.parts.first { $0.id == marked.id } ?? Self.placeholder },
                set: { changed in inventory = inventory?.with(parts: inventory?.parts.map { $0.id == changed.id ? changed : $0 } ?? []) }
            ))
        }
        .navigationTitle("Parts")
        .navigationBarTitleDisplayMode(.inline)
        .background(Palette.background)
        .task {
            guard result == nil else { return }
            let schema = GeminiSchema.firebase(PartsReader.responseSchema)
            let read = await PartsStep.read(photo: photo, box: box, scanID: scanID) { prompt, image in
                try await GeminiClient().json(prompt: prompt, image: image, schema: schema)
            }
            result = read
            inventory = read.inventory
        }
    }

    private func confirm(_ result: PartsResult, _ inventory: Inventory) -> some View {
        List {
            Section {
                Label(result.fromGemini ? "Read by Gemini from your photo" : "Estimated from the measured size",
                      systemImage: result.fromGemini ? "sparkles" : "ruler")
                    // One element: VoiceOver reads the words once, and tests never land on the bare icon.
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("partsSource")
                ForEach(result.flags, id: \.message) { flag in
                    Label(flag.message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("partsFlag")
                }
            }
            Section("Confirm the parts") {
                ForEach(inventory.parts, id: \.id) { part in partRow(part) }
            }
            Section {
                NavigationLink {
                    IdeasView(inventory: inventory)
                } label: {
                    Label("See what it can become", systemImage: "lightbulb").font(.headline)
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .accessibilityIdentifier("planFromParts")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.brand)
    }

    private func partRow(_ part: Part) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack {
                Text(ProofModel.displayName(part.id)).font(.headline)
                if part.damaged {
                    Text("Damaged").font(.caption.weight(.semibold)).foregroundStyle(Palette.fails)
                }
            }
            Text(String(format: "%.1f × %.1f cm, %.0f mm thick", part.widthMm / 10, part.heightMm / 10, part.thicknessMm))
                .font(.subheadline).foregroundStyle(Palette.secondaryText)
            Picker("Material", selection: Binding(
                get: { part.material },
                set: { if let current = inventory { inventory = PartsStep.setting($0, of: part.id, in: current) } }
            )) {
                ForEach(Self.materials, id: \.0) { Text($0.1).tag($0.0) }
            }
            .accessibilityIdentifier("material-\(part.id)")
            Button {
                markingHolesOf = part.id
            } label: {
                Label(part.keepOuts.isEmpty ? "Mark screw holes" : "\(part.keepOuts.count) screw holes marked",
                      systemImage: "smallcircle.filled.circle")
                    .font(.subheadline)
                    .frame(minHeight: TapTarget.minimum)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("holes-\(part.id)")
        }
        .padding(.vertical, Spacing.xSmall)
    }
}
