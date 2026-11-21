import GinkgoCore
import SwiftUI

/// A panel drawn to scale: tap where its screw holes are, so no cut goes through them.
struct ScrewHolesView: View {
    @Binding var part: Part
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text("Tap each screw hole on the \(ProofModel.displayName(part.id).lowercased()). Tap a hole again to remove it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                GeometryReader { geometry in
                    let size = geometry.size
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Palette.brand.opacity(0.08))
                            .stroke(Palette.brand, lineWidth: 1.5)
                        ForEach(Array(part.keepOuts.enumerated()), id: \.offset) { _, hole in
                            let point = ScrewHoles.point(of: hole, on: part)
                            Circle().fill(Palette.fails).frame(width: 14, height: 14)
                                .position(x: point.x * size.width, y: point.y * size.height)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        part = ScrewHoles.toggling(at: CGPoint(x: location.x / size.width, y: location.y / size.height), on: part)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .aspectRatio(part.widthMm / part.heightMm, contentMode: .fit)
                .accessibilityElement()
                .accessibilityLabel("\(ProofModel.displayName(part.id)), \(part.keepOuts.count) screw holes marked")
                .accessibilityIdentifier("holePanel")
                Text(String(format: "%.1f × %.1f cm · %d marked", part.widthMm / 10, part.heightMm / 10, part.keepOuts.count))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("holeCount")
                Spacer(minLength: 0)
            }
            .padding(Spacing.large)
            .navigationTitle("Screw holes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("holesDone")
                }
            }
        }
        .tint(Palette.brand)
    }
}
