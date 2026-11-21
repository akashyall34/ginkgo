import SwiftUI

/// One original panel drawn to scale, with the pieces cut from it and its screw holes.
struct CuttingDiagramView: View {
    let sheet: ProofModel.Sheet

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(String(format: "%@ · %.1f × %.1f cm", sheet.name, sheet.part.widthMm / 10, sheet.part.heightMm / 10))
                .font(.subheadline.weight(.semibold))
            Canvas { context, size in draw(in: &context, size: size) }
                .aspectRatio(sheet.part.widthMm / sheet.part.heightMm, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("sheet")
    }

    private var accessibilityText: String {
        let cuts = sheet.cuts.map { ProofModel.displayName($0.newPart) }.joined(separator: ", ")
        return "\(sheet.name): cut \(cuts)."
    }

    /// Schema rectangles start at the panel's bottom-left; the canvas starts top-left.
    private func rect(_ mm: CGRect, scale: Double, size: CGSize) -> CGRect {
        CGRect(x: mm.minX * scale, y: size.height - mm.maxY * scale, width: mm.width * scale, height: mm.height * scale)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = size.width / sheet.part.widthMm
        let panel = CGRect(origin: .zero, size: size)
        context.fill(Path(roundedRect: panel, cornerRadius: 4), with: .color(Palette.brand.opacity(0.06)))
        context.stroke(Path(roundedRect: panel.insetBy(dx: 1, dy: 1), cornerRadius: 4), with: .color(.secondary), lineWidth: 1.5)

        for cut in sheet.cuts {
            let r = rect(CGRect(x: cut.xMm, y: cut.yMm, width: cut.widthMm, height: cut.heightMm), scale: scale, size: size)
            context.fill(Path(r), with: .color(Palette.brand.opacity(0.25)))
            context.stroke(Path(r), with: .color(Palette.brand), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            let label = Text(String(format: "%@\n%.0f × %.0f mm", ProofModel.displayName(cut.newPart), cut.widthMm, cut.heightMm))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.brand)
            context.draw(label, at: CGPoint(x: r.midX, y: r.midY))
        }

        for hole in sheet.part.keepOuts {
            let r = rect(CGRect(x: hole.xMm, y: hole.yMm, width: hole.widthMm, height: hole.heightMm), scale: scale, size: size)
            let marker = CGRect(x: r.midX - 5, y: r.midY - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: marker), with: .color(Palette.fails))
        }
    }
}
