import SwiftUI

struct GuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            HStack(spacing: 7) {
                Image("GinkgoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("Ginkgo")
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(Palette.brand)
            }
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("How to use Ginkgo")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Palette.brand)
                    .accessibilityIdentifier("guideTitle")

                Text("Measure a piece of furniture in a few simple steps.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Spacing.small) {
                guideStep(
                    number: "01",
                    title: "Start a scan",
                    detail: "Tap Snap furniture and allow camera access. " +
                        "Scanning requires an iPhone with LiDAR, such as iPhone 12 Pro or later Pro models."
                )

                guideStep(
                    number: "02",
                    title: "Frame one flat face",
                    detail: "Aim at a flat, rectangular surface on your furniture. " +
                        "Hold the phone steady and keep the whole face in view."
                )

                guideStep(
                    number: "03",
                    title: "Capture and select",
                    detail: "Tap Capture. If Ginkgo outlines the face, tap it. " +
                        "If it doesn't, choose Place corners to mark the face yourself."
                )

                guideStep(
                    number: "04",
                    title: "Check the corners",
                    detail: "Drag each corner onto the edge of the face. " +
                        "The measured width and height appear in centimeters and inches, with an uncertainty estimate."
                )
            }

            Label("Need another try? Tap Retake to capture a new frame.", systemImage: "arrow.counterclockwise")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.brand.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

            NavigationLink {
                ScanView(source: FrameSources.makeDefault())
            } label: {
                Label("Start a scan", systemImage: "camera")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Palette.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("guideStartScan")
            .padding(.bottom, 112)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guideStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(Palette.brand)
                .frame(width: 36, height: 36)
                .background(Palette.brand.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.brand.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }
}
