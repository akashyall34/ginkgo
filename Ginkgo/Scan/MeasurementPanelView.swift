import SwiftUI

/// The result and the next instruction, under the photo.
///
/// Its height never changes between states: an invisible template of the tallest
/// content reserves the space. Otherwise the photo above resizes whenever the message
/// changes, and the face's corners jump under the person's finger.
struct MeasurementPanelView: View {
    let model: ScanModel

    /// The longest instruction the screen shows, used only to reserve space.
    static let longestInstruction = PlaneMeasureError.notEnoughSurface(usable: 99, needed: 99).explanation

    var body: some View {
        ZStack(alignment: .top) {
            lines(size: "00.0 × 00.0 cm", detail: "± 0.0 cm  ·  00.0 × 00.0 in", instruction: Self.longestInstruction,
                  isProblem: false)
                .hidden()
                .accessibilityHidden(true)
            lines(size: sizeText, detail: detailText, instruction: model.instruction, isProblem: isProblem)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityIdentifier("result")
    }

    private func lines(size: String?, detail: String?, instruction: String, isProblem: Bool) -> some View {
        VStack(spacing: Spacing.xSmall) {
            Text(size ?? " ")
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(Palette.brand)
                .opacity(size == nil ? 0 : 1)
            Text(detail ?? " ")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .opacity(detail == nil ? 0 : 1)
            Text(instruction)
                .font(.callout)
                .foregroundStyle(isProblem ? Palette.fails : .secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var measurement: QuadResult? {
        if case .measured(let r) = model.status { return r }
        return nil
    }

    private var sizeText: String? {
        measurement.map { MeasurementFormat.size(widthMeters: $0.width, heightMeters: $0.height) }
    }

    private var detailText: String? {
        measurement.map {
            MeasurementFormat.plusMinus(meters: $0.uncertainty) + "  ·  "
                + MeasurementFormat.inches(widthMeters: $0.width, heightMeters: $0.height)
        }
    }

    private var isProblem: Bool {
        if case .problem = model.status { return true }
        return false
    }

    private var spokenLabel: String {
        guard let r = measurement else { return model.instruction }
        let size = MeasurementFormat.spoken(widthMeters: r.width, heightMeters: r.height, uncertaintyMeters: r.uncertainty)
        return size + ". " + model.instruction
    }
}
