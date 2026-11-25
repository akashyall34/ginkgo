import GinkgoCore
import SwiftUI

/// Take it apart, step by step: what comes off in what order, how it's held, and the tools for it.
struct TakeApartView: View {
    @State private var model: TakeApartModel

    init(inventory: Inventory, photo: Data?) {
        _model = State(initialValue: TakeApartModel(inventory: inventory, photo: photo))
    }

    var body: some View {
        Group {
            if let guide = model.guide {
                list(guide)
            } else {
                ProgressView("Reading how it's put together…").accessibilityIdentifier("takeApartLoading")
            }
        }
        .background(Palette.background)
        .tint(Palette.brand)
        .navigationTitle("Take it apart")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard model.guide == nil else { return }
            let offline = GeminiAgentModel.isDisabled
            let online = offline ? false : await Connectivity.isOnline()
            let schema = GeminiSchema.firebase(TakeApart.responseSchema)
            await model.load(online: online, modelName: GeminiAgentModel().modelName) { prompt, image in
                try await GeminiClient().json(prompt: prompt, image: image, schema: schema)
            }
            if let entry = model.entry { try? RoutingLogStore.standard().append([entry]) }
        }
    }

    private func list(_ guide: TakeApartGuide) -> some View {
        List {
            Section {
                Label(model.sourceLine, systemImage: guide.source == .gemini ? "sparkles" : "list.number")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("takeApartSource")
                ForEach(guide.notes, id: \.self) { note in
                    Label(note, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("takeApartNote")
                }
            }
            Section {
                ForEach(guide.steps, id: \.number) { step in row(step) }
            } header: {
                SectionTitle(model.progress).accessibilityIdentifier("takeApartProgress")
            } footer: {
                Text("Keep the screws and brackets: the build may reuse them. Scan each panel once it's off.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ step: TakeApartStep) -> some View {
        let isDone = model.done.contains(step.number)
        return Button {
            model.toggle(step.number)
        } label: {
            HStack(alignment: .top, spacing: Spacing.medium) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "\(step.number).circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Palette.verified : Palette.brand)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    if !step.partIDs.isEmpty {
                        Text(step.partIDs.map { Format.partName($0) }.joined(separator: ", ").capitalizedFirst)
                            .font(.headline)
                    }
                    Text(step.action).fixedSize(horizontal: false, vertical: true)
                    if !step.tools.isEmpty {
                        Label(step.tools, systemImage: "wrench.and.screwdriver")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(.primary)
                .strikethrough(isDone, color: Palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: TapTarget.minimum, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.number). \(step.action) \(step.tools)")
        .accessibilityValue(isDone ? "Done" : "Not done")
        .accessibilityHint("Double-tap to mark it \(isDone ? "not done" : "done")")
        .accessibilityIdentifier("takeApartStep-\(step.number)")
    }
}
