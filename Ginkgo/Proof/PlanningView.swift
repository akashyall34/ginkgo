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
                // While planning, the headline says where; the badge confirms where the result came from.
                if let route = model.route, !model.isRunning { RouteBadge(route: route) }
                if !model.isRunning { StepStoryView(trace: model.steps) }
                if let reason = model.fallbackReason {
                    Text(reason).font(.footnote).foregroundStyle(Palette.secondaryText).accessibilityIdentifier("fallbackReason")
                }
            }
            if !model.steps.isEmpty {
                Section("Every step, checked") {
                    ForEach(model.steps, id: \.index) { AgentStepView(step: $0) }
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
            // Offline test runs (-noGemini) switch off both models: no network, no on-device model.
            let offlineTest = GeminiAgentModel.isDisabled
            let online = offlineTest ? false : await Connectivity.isOnline()
            let planner = HybridPlanner(
                device: OnDevicePlanner(enabled: !offlineTest),
                cloud: { inventory, request, onStep in
                    await PlanAgent(model: GeminiAgentModel(), maxTurns: 6)
                        .run(inventory: inventory, limits: nil, request: request, onStep: onStep)
                },
                cloudModelName: GeminiAgentModel().modelName)
            await model.run(planner: planner, online: online, request: request)
            try? RoutingLogStore.standard().append(model.routing)
        }
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
        case .info: return Palette.secondaryText
        }
    }
}

/// Where the plan was made, and why: "Planned on this iPhone", "Sent to Gemini: …", or the rules offline.
struct RouteBadge: View {
    let route: Route

    var body: some View {
        Label(route.reason.message, systemImage: Self.icon(route.venue))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.brand)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("routeBadge")
    }

    static func icon(_ venue: Venue) -> String {
        switch venue {
        case .device: return "iphone"
        case .cloud: return "cloud"
        case .code: return "checkmark.shield"
        }
    }
}
