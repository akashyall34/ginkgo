import SwiftUI

/// A bar showing how much of the allowed sag a shelf or seat uses, with a marker at
/// the limit. Past the limit the bar turns red.
struct SagGaugeView: View {
    let row: ProofModel.SagRow

    /// The bar shows up to 150% of the limit, so a failure is visibly past the marker.
    private static let fullScale = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            SplitRow {
                Text(row.name).font(.body.weight(.semibold))
            } trailing: {
                Text(row.summary).font(.footnote.monospacedDigit()).foregroundStyle(Palette.secondaryText)
            }
            GeometryReader { geo in
                let fill = min(row.shareOfLimit, Self.fullScale) / Self.fullScale
                let limitX = geo.size.width / Self.fullScale
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(row.passes ? Palette.verified : Palette.fails)
                        .frame(width: max(6, geo.size.width * fill))
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 2)
                        .offset(x: limitX - 1)
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name) sag: \(row.summary). " + (row.passes ? "Within the limit." : "Over the limit."))
        .accessibilityIdentifier("sag")
    }
}
