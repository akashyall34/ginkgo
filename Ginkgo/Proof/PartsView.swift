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

    /// Every material the validator knows. Only solid wood and plywood get cut; the rest are reused whole.
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
                    .accessibilityIdentifier("partsSource")
                ForEach(result.flags, id: \.message) { flag in
                    Label(flag.message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("partsFlag")
                }
            }
            Section("Confirm the parts") {
                ForEach(inventory.parts, id: \.id) { part in partRow(part) }
            }
            Section {
                NavigationLink {
                    switch LivePlan.proof(from: inventory) {
                    case .success(let model): ProofView(model: model)
                    case .failure(let failure):
                        ContentUnavailableView("No plan fits", systemImage: "ruler", description: Text(failure.explanation))
                    }
                } label: {
                    Label("Make a plan", systemImage: "hammer").font(.headline)
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .accessibilityIdentifier("planFromParts")
            }
        }
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
                .font(.subheadline).foregroundStyle(.secondary)
            Picker("Material", selection: Binding(
                get: { part.material },
                set: { if let current = inventory { inventory = PartsStep.setting($0, of: part.id, in: current) } }
            )) {
                ForEach(Self.materials, id: \.0) { Text($0.1).tag($0.0) }
            }
            .accessibilityIdentifier("material-\(part.id)")
        }
        .padding(.vertical, Spacing.xSmall)
    }
}
