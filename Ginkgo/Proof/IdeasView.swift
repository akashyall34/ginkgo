import GinkgoCore
import SwiftUI

/// What the confirmed parts can become, with what each saves. Tapping one plans it with Gemini,
/// checked by Ginkgo at every step.
struct IdeasView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The icon tile grows with the title beside it, so a large icon never spills out of it.
    @ScaledMetric(relativeTo: .title3) private var iconBox: CGFloat = TapTarget.minimum
    let inventory: Inventory

    var body: some View {
        List {
            Section {
                ForEach(Idea.options(for: inventory)) { idea in
                    NavigationLink {
                        PlanningView(inventory: inventory, request: idea.request)
                    } label: {
                        card(idea)
                    }
                    .accessibilityIdentifier("idea-\(idea.rawValue)")
                }
            } footer: {
                Text((Idea.canCut(inventory) ? "" : Idea.noCutReason + " ")
                     + "Reuse and area come from your measurements and the validated plan.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.brand)
        .navigationTitle("Ideas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ idea: Idea) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            let header = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
                : AnyLayout(HStackLayout(spacing: Spacing.small))
            header {
                Image(systemName: idea.icon)
                    .font(.title3)
                    .foregroundStyle(Palette.brand)
                    .frame(width: iconBox, height: iconBox)
                    .background(Palette.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                Text(idea.title).font(.title3.weight(.semibold))
            }
            if idea == .bench, let bench = RuleBasedPlanner.bench(inventory: inventory) {
                let impact = Impact.of(plan: bench.plan, inventory: inventory, result: bench.validation)
                Text(impact.summary).font(.subheadline.monospacedDigit())
                Text(impact.difficulty).font(.footnote).foregroundStyle(Palette.secondaryText)
            } else {
                Text("Gemini plans it; Ginkgo proves it fits.").font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(.vertical, Spacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}
