import GinkgoCore
import SwiftUI

/// The planner at work: each step Gemini takes and what Ginkgo's checks said, then the proven plan.
struct PlanningView: View {
    @State private var model: PlanningModel
    let request: String

    init(inventory: Inventory, request: String = Prompts.defaultRequest) {
        _model = State(initialValue: PlanningModel(inventory: inventory))
        self.request = request
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.small) {
                    if model.isRunning { ProgressView() }
                    Text(model.headline).font(.headline).accessibilityIdentifier("planningHeadline")
                }
                if let reason = model.fallbackReason {
                    Text(reason).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("fallbackReason")
                }
            }
            if !model.steps.isEmpty {
                Section("Every step, checked") {
                    ForEach(model.steps, id: \.index) { stepRow($0) }
                }
            }
            if let proof = model.proof {
                Section {
                    NavigationLink {
                        ProofView(model: proof)
                    } label: {
                        Label("See the proof", systemImage: "checkmark.seal").font(.headline)
                            .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                    }
                    .accessibilityIdentifier("seeProof")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.brand)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard model.outcome == nil else { return }
            await model.run(model: GeminiAgentModel(), request: request)
        }
    }

    private func stepRow(_ step: AgentStep) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Label(step.summary, systemImage: Self.icon(step.status))
                .foregroundStyle(Self.color(step.status))
                .font(.subheadline.weight(.semibold))
            if !step.reason.isEmpty {
                Text("“\(step.reason)”").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("agentStep")
    }

    static func icon(_ status: GinkgoCore.Status) -> String {
        switch status {
        case .pass, .accepted: return "checkmark.circle.fill"
        case .fail, .error: return "xmark.circle.fill"
        case .info: return "info.circle"
        }
    }

    static func color(_ status: GinkgoCore.Status) -> Color {
        switch status {
        case .pass, .accepted: return Palette.verified
        case .fail, .error: return Palette.fails
        case .info: return .secondary
        }
    }
}
