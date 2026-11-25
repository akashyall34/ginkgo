import GinkgoCore
import SwiftUI

/// Scan each cut piece; Ginkgo says good, trim, use as is, or recut, before anything is assembled.
struct CutCheckView: View {
    @State private var model: CutCheckModel
    @State private var scanning: String?

    init(plan: Plan, result: ValidationResult, inventory: Inventory) {
        _model = State(initialValue: CutCheckModel(plan: plan, result: result, inventory: inventory))
    }

    var body: some View {
        List {
            Section {
                Text(model.summary).font(.headline).accessibilityIdentifier("cutCheckSummary")
                if model.readyToAssemble {
                    NavigationLink {
                        AssemblyView(plan: model.plan, inventory: model.inventory)
                    } label: {
                        Label("Assemble", systemImage: "cube.transparent").font(.headline)
                            .frame(minHeight: TapTarget.minimum)
                    }
                    .accessibilityIdentifier("assembleFromCheck")
                }
            }
            Section(titled: "Pieces") {
                ForEach(model.pieces, id: \.self) { pieceRow($0) }
            }
            if !model.supportWarnings.isEmpty {
                Section(titled: "Supports") {
                    ForEach(model.supportWarnings, id: \.self) {
                        Label($0, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.fails)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("supportWarning")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.brand)
        .navigationTitle("Check the pieces")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $scanning) { piece in
            ScanView(source: FrameSources.makeDefault()) { result in
                model.record(piece: piece, widthMeters: result.width, heightMeters: result.height)
                scanning = nil
            }
        }
    }

    private func pieceRow(_ piece: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            SplitRow {
                Text(ProofModel.displayName(piece)).font(.headline)
            } trailing: {
                Button(model.results[piece] == nil ? "Scan" : "Scan again") { scanning = piece }
                    .buttonStyle(.bordered)
                    .frame(minHeight: TapTarget.minimum)
                    .accessibilityIdentifier("scanPiece-\(piece)")
            }
            if let result = model.results[piece] {
                Label(result.message, systemImage: Self.icon(result.verdict))
                    .font(.subheadline)
                    .foregroundStyle(Self.color(result.verdict))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("pieceVerdict-\(piece)")
            }
        }
        .padding(.vertical, Spacing.xSmall)
    }

    static func icon(_ verdict: CutVerdict) -> String {
        switch verdict {
        case .good, .useAsIs: return "checkmark.circle.fill"
        case .trim: return "scissors"
        case .recut: return "xmark.circle.fill"
        }
    }

    static func color(_ verdict: CutVerdict) -> Color {
        switch verdict {
        case .good, .useAsIs: return Palette.verified
        case .trim: return Palette.brand
        case .recut: return Palette.fails
        }
    }
}
