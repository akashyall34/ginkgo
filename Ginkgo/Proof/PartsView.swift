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
    @State private var online = false
    @State private var rereading = false

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
            let read = await readPhoto()
            result = read
            inventory = read.inventory
        }
        // Offers "Read the parts from the photo" when the network comes back after an offline estimate.
        .task {
            guard !GeminiAgentModel.isDisabled else { return }
            for await isOnline in Connectivity.updates() { online = isOnline }
        }
    }

    private func readPhoto() async -> PartsResult {
        let schema = GeminiSchema.firebase(PartsReader.responseSchema)
        return await PartsStep.read(photo: photo, box: box, scanID: scanID) { prompt, image in
            try await GeminiClient().json(prompt: prompt, image: image, schema: schema)
        }
    }

    private func reread(_ current: PartsResult, _ edited: Inventory) async {
        rereading = true
        let read = PartsStep.reread(edited: edited, flags: current.flags, attempt: await readPhoto())
        result = read
        inventory = read.inventory
        rereading = false
    }

    private func rereadButton(_ result: PartsResult, _ inventory: Inventory) -> some View {
        Button {
            Task { await reread(result, inventory) }
        } label: {
            HStack(spacing: Spacing.small) {
                if rereading { ProgressView() }
                Label(rereading ? "Gemini is reading the photo…" : "You're online: read the parts from the photo",
                      systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }
            .frame(minHeight: TapTarget.minimum)
            .accessibilityElement(children: .combine)
        }
        .disabled(rereading)
        .accessibilityHint("Replaces the estimate with Gemini's reading, which you confirm again")
        .accessibilityIdentifier("rereadParts")
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
                if rereading || PartsStep.canReread(result, hasPhoto: photo != nil, online: online) {
                    rereadButton(result, inventory)
                }
            }
            Section(titled: "Confirm the parts") {
                ForEach(inventory.parts, id: \.id) { part in
                    partRow(part)
                    // Its own row: a list row treats a tap anywhere as a tap on its first control, so a second
                    // picker in the material's row would open the material menu instead.
                    if part.material == .solidWood { grainPicker(part) }
                }
            }
            Section {
                NavigationLink {
                    TakeApartView(inventory: inventory, photo: photo)
                } label: {
                    Label("How to take it apart", systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum, alignment: .leading)
                }
                .accessibilityIdentifier("takeApart")
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
            Text(PartsStep.sizeLine(part))
                .font(.subheadline).foregroundStyle(Palette.secondaryText)
            Picker("Material", selection: Binding(
                get: { part.material },
                set: { if let current = inventory { inventory = PartsStep.setting($0, of: part.id, in: current) } }
            )) {
                ForEach(Self.materials, id: \.0) { Text($0.1).tag($0.0) }
            }
            .accessibilityIdentifier("material-\(part.id)")
            if let note = PartsStep.materialNote(part) {
                Button {
                    if let current = inventory { inventory = PartsStep.setting(part.material, of: part.id, in: current) }
                } label: {
                    Label(note, systemImage: "questionmark.circle")
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: TapTarget.minimum)
                }
                .buttonStyle(.borderless)
                .accessibilityHint("Confirms the material shown above")
                .accessibilityIdentifier("confirmMaterial-\(part.id)")
            }
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

    /// Which way a solid-wood panel's grain runs: unchecked, it's rated as across the grain.
    @ViewBuilder private func grainPicker(_ part: GinkgoCore.Part) -> some View {
        Picker("Wood lines", selection: Binding(
            get: { part.grain },
            set: { grain in
                if let grain, let current = inventory { inventory = PartsStep.setting(grain: grain, of: part.id, in: current) }
            }
        )) {
            Text("Not checked").tag(Grain?.none)
            Text("Side to side").tag(Grain?.some(.alongWidth))
            Text("Top to bottom").tag(Grain?.some(.alongHeight))
        }
        .accessibilityIdentifier("grain-\(part.id)")
        if let note = PartsStep.grainNote(part) {
            Text(note).font(.footnote).foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
