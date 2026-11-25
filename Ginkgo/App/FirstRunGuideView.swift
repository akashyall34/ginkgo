import SwiftUI

/// The pages of the first-run guide, with Skip, Next, and on the last page the two ways in.
struct FirstRunGuideView: View {
    let onFinish: () -> Void
    let onTrySample: () -> Void
    @State private var page = 0

    private var isLast: Bool { page == FirstRunGuide.pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("Skip", action: onFinish)
                        .frame(minWidth: TapTarget.minimum, minHeight: TapTarget.minimum)
                        .accessibilityIdentifier("firstRunSkip")
                }
            }
            .padding(.horizontal, Spacing.large)
            TabView(selection: $page) {
                ForEach(FirstRunGuide.pages) { item in
                    pageView(item).tag(item.id)
                }
            }
            // Our own dots, below the pages: the system's sit on top of the text at large sizes.
            .tabViewStyle(.page(indexDisplayMode: .never))
            dots
            actions
        }
        .background(Palette.background)
        .tint(Palette.brand)
    }

    private var dots: some View {
        HStack(spacing: Spacing.small) {
            ForEach(FirstRunGuide.pages) { item in
                Circle()
                    .fill(item.id == page ? Palette.brand : Palette.secondaryText.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(FirstRunGuide.pages.count)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("firstRunDots")
    }

    private func pageView(_ item: FirstRunPage) -> some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                Image(systemName: item.symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.brand)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(item.detail)
                    .font(.body)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstRunPage-\(item.id)")
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: Spacing.small) {
            if isLast {
                Button(action: onTrySample) {
                    Label("Try a sample", systemImage: "tray.full")
                        .font(.headline)
                        .foregroundStyle(Palette.onBrand)
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("firstRunSample")
                Button(action: onFinish) {
                    Text("Get started").font(.headline).frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("firstRunStart")
            } else {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("Next").font(.headline).foregroundStyle(Palette.onBrand)
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("firstRunNext")
            }
        }
        .padding(Spacing.large)
    }
}
