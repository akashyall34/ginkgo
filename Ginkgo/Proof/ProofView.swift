import GinkgoCore
import SwiftUI

/// The Proof screen: whether a plan fits, piece by piece, with sag and a cutting diagram.
struct ProofView: View {
    let model: ProofModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                VerdictHeaderView(model: model)
                section("Pieces") {
                    ForEach(Array(model.cuts.enumerated()), id: \.offset) { _, row in CutRowView(row: row) }
                    ForEach(model.otherProblems, id: \.self) { ProblemText(text: $0) }
                }
                if !model.sagRows.isEmpty {
                    section("Sag under load") {
                        ForEach(Array(model.sagRows.enumerated()), id: \.offset) { _, row in SagGaugeView(row: row) }
                    }
                }
                if !model.sheets.isEmpty {
                    section("Cutting plan") {
                        ForEach(Array(model.sheets.enumerated()), id: \.offset) { _, sheet in CuttingDiagramView(sheet: sheet) }
                    }
                }
                if !model.checksBeforeCutting.isEmpty {
                    section("Check before cutting") {
                        ForEach(model.checksBeforeCutting, id: \.self) { check in
                            Label(check, systemImage: "ruler")
                                .font(.callout)
                                .accessibilityIdentifier("check")
                        }
                    }
                }
                if model.verdict == .proven {
                    VStack(spacing: Spacing.small) {
                        NavigationLink {
                            TransformView(scene: TransformLayout.scene(plan: model.plan, inventory: model.inventory))
                        } label: {
                            Label("See it built", systemImage: "cube.transparent")
                                .font(.headline)
                                .foregroundStyle(Palette.onBrand)
                                .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.brand)
                        .accessibilityIdentifier("seeItBuilt")
                        NavigationLink {
                            VerifyView(plan: model.plan, inventory: model.inventory, result: model.result)
                        } label: {
                            Label("Verify before cutting", systemImage: "ruler")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.brand)
                        .accessibilityIdentifier("verify")
                    }
                }
            }
            .padding(Spacing.medium)
        }
        .background(Palette.background)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The big answer at the top: proven, or how many problems.
struct VerdictHeaderView: View {
    let model: ProofModel

    private var proven: Bool { model.verdict == .proven }

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: proven ? "checkmark.seal.fill" : "xmark.octagon.fill")
                .font(.system(.largeTitle))
                .foregroundStyle(proven ? Palette.verified : Palette.fails)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(model.headline)
                    .font(.title2.bold())
                    .foregroundStyle(proven ? Palette.verified : Palette.fails)
                Text(model.reuse)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("verdict")
    }
}

/// One planned piece: fits, or what's wrong with it.
struct CutRowView: View {
    let row: ProofModel.CutRow
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: row.fits ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(row.fits ? Palette.verified : Palette.fails)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                let line = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xSmall))
                    : AnyLayout(HStackLayout())
                line {
                    Text(row.name).font(.body.weight(.semibold))
                    if !typeSize.isAccessibilitySize { Spacer() }
                    Text(row.size).font(.body.monospacedDigit())
                }
                Text(row.source).font(.footnote).foregroundStyle(Palette.secondaryText)
                ForEach(row.problems, id: \.self) { ProblemText(text: $0) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(row.size), \(row.source.lowercased()). "
                            + (row.fits ? "Fits." : row.problems.joined(separator: " ")))
        .accessibilityIdentifier("cut")
    }
}

struct ProblemText: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(Palette.fails)
    }
}
