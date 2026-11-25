import GinkgoCore
import SwiftUI

/// What the plan keeps out of the trash: numbers computed from the plan itself, then the one sourced statistic.
struct ImpactView: View {
    let impact: ImpactSummary

    var body: some View {
        List {
            Section {
                Label(impact.headline, systemImage: "leaf.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.verified)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("impactHeadline")
                Text(impact.areaLine).accessibilityIdentifier("impactArea")
                Text(impact.panelsLine).accessibilityIdentifier("impactPanels")
                Text(ImpactSummary.note)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section(titled: "Why it matters") {
                Text(ImpactFacts.sentence)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("impactFact")
                if let url = URL(string: ImpactFacts.sourceURL) {
                    Link(destination: url) {
                        Label(ImpactFacts.sourceName, systemImage: "link")
                            .font(.footnote)
                            .frame(minHeight: TapTarget.minimum, alignment: .leading)
                    }
                    .accessibilityIdentifier("impactSource")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.brand)
        .navigationTitle("Impact")
        .navigationBarTitleDisplayMode(.inline)
    }
}
