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
    /// The longest thickness line (a refusal), reserving its space in flat-panel mode.
    static let longestThickness = [ThicknessError.notEnoughFace(usable: 0, needed: 0), .notEnoughFloor(usable: 0, needed: 0),
                                   .notFlat(degrees: 0), .tooThin(meters: 0), .tooThick(meters: 0), .tooUncertain(meters: 0)]
        .map(\.explanation).max { $0.count < $1.count } ?? ""

    var body: some View {
        ZStack(alignment: .top) {
            lines(size: "00.0 × 00.0 cm", detail: "± 0.0 cm  ·  00.0 × 00.0 in",
                  thickness: model.measuresThickness ? ThicknessLine(text: Self.longestThickness, isProblem: false) : nil,
                  instruction: Self.longestInstruction, isProblem: false)
                .hidden()
                .accessibilityHidden(true)
            lines(size: sizeText, detail: detailText, thickness: thicknessLine, instruction: model.instruction,
                  isProblem: isProblem)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityIdentifier("result")
    }

    /// The thickness reading, or why there isn't one (shown as a problem).
    struct ThicknessLine {
        let text: String
        let isProblem: Bool
    }

    private func lines(size: String?, detail: String?, thickness: ThicknessLine?, instruction: String,
                       isProblem: Bool) -> some View {
        VStack(spacing: Spacing.xSmall) {
            Text(size ?? " ")
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(Palette.brand)
                .opacity(size == nil ? 0 : 1)
            Text(detail ?? " ")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Palette.secondaryText)
                .opacity(detail == nil ? 0 : 1)
            if let thickness {
                Text(thickness.text)
                    .font(thickness.isProblem ? .callout : .headline.monospacedDigit())
                    .foregroundStyle(thickness.isProblem ? Palette.fails : Palette.brand)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("thickness")
            }
            Text(instruction)
                .font(.callout)
                .foregroundStyle(isProblem ? Palette.fails : Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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

    /// In flat-panel mode: the thickness once measured, or why it couldn't be. Nil otherwise.
    private var thicknessLine: ThicknessLine? {
        guard model.measuresThickness, measurement != nil else { return nil }
        if let t = model.thickness {
            return ThicknessLine(text: MeasurementFormat.thickness(meters: t.thickness, uncertaintyMeters: t.uncertainty),
                                 isProblem: false)
        }
        return model.thicknessProblem.map { ThicknessLine(text: $0, isProblem: true) }
    }

    private var isProblem: Bool {
        if case .problem = model.status { return true }
        return false
    }

    private var spokenLabel: String {
        guard let r = measurement else { return model.instruction }
        let size = MeasurementFormat.spoken(widthMeters: r.width, heightMeters: r.height, uncertaintyMeters: r.uncertainty)
        let thick = model.thickness.map {
            ". " + MeasurementFormat.spokenThickness(meters: $0.thickness, uncertaintyMeters: $0.uncertainty)
        } ?? model.thicknessProblem.map { ". " + $0 } ?? ""
        return size + thick + ". " + model.instruction
    }
}
