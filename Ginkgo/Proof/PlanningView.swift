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
            if model.canImprove || model.isImproving || model.improvement != nil { improveSection }
            if !model.steps.isEmpty {
                Section(titled: "Every step, checked") {
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
            let online = Self.offlineTest ? false : await Connectivity.isOnline()
            await model.run(planner: Self.planner(), online: online, request: request)
            try? RoutingLogStore.standard().append(model.routing)
            await backUpPlan()
        }
        // Keeps "Improve this plan" in step with the network: it appears when the connection comes back.
        .task {
            guard !Self.offlineTest else { return }
            for await online in Connectivity.updates() { model.online = online }
        }
    }

    @ViewBuilder private var improveSection: some View {
        Section {
            if let improvement = model.improvement {
                Label(improvement.message, systemImage: improvement.choice == .improved ? "cloud" : "checkmark.shield")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("improvementResult")
            } else {
                Button {
                    Task {
                        await model.improve(planner: Self.planner(), request: request)
                        if let last = model.routing.last { try? RoutingLogStore.standard().append([last]) }
                        await backUpPlan()
                    }
                } label: {
                    HStack(spacing: Spacing.small) {
                        if model.isImproving { ProgressView() }
                        Label(model.isImproving ? "Gemini is replanning in the cloud…" : "Improve this plan",
                              systemImage: "cloud")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                    .accessibilityElement(children: .combine)
                }
                .disabled(model.isImproving)
                .accessibilityIdentifier("improvePlan")
            }
        } footer: {
            if model.improvement == nil {
                Text("You're online. Gemini replans the same parts; Ginkgo checks its plan and keeps the one that "
                     + "reuses more wood.")
            }
        }
    }

    /// A plan that passed is backed up, when the person has turned backup on.
    private func backUpPlan() async {
        guard let plan = model.outcome?.plan, let validation = model.outcome?.validation, validation.passes else { return }
        await CloudBackup.shared.backUp(.plan(plan, validation: validation, route: model.route, date: Date()))
    }

    /// Offline test runs (-noGemini) switch off both models: no network, no on-device model.
    static var offlineTest: Bool { GeminiAgentModel.isDisabled }

    /// Apple's on-device model from iOS 26; before that, a stand-in that is never available.
    static func devicePlanner() -> any DevicePlanning {
        if #available(iOS 26.0, *) { return OnDevicePlanner(enabled: !offlineTest) }
        return NoDevicePlanner()
    }

    static func planner() -> HybridPlanner {
        HybridPlanner(
            device: devicePlanner(),
            cloud: { inventory, request, onStep in
                await PlanAgent(model: GeminiAgentModel(), maxTurns: 6)
                    .run(inventory: inventory, limits: nil, request: request, onStep: onStep)
            },
            cloudModelName: GeminiAgentModel().modelName)
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
