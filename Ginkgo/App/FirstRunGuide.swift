import Foundation

/// One page of the first-run guide.
struct FirstRunPage: Equatable, Identifiable {
    let id: Int
    let symbol: String
    let title: String
    let detail: String
}

/// The first-run guide: the whole flow in five pages, shown once on Home and skippable. Its words describe only what
/// the app does.
enum FirstRunGuide {
    static let seenKey = "hasSeenFirstRunGuide"

    static let pages = [
        FirstRunPage(id: 0, symbol: "viewfinder", title: "Scan the furniture",
                     detail: "Point your iPhone's LiDAR at one flat face. Ginkgo measures its width and height, and a "
                         + "flat-panel scan reads the thickness, so you don't need a tape."),
        FirstRunPage(id: 1, symbol: "wrench.and.screwdriver", title: "Take it apart",
                     detail: "Ginkgo lists what comes off in what order, how each part is held, and the tools to use."),
        FirstRunPage(id: 2, symbol: "checkmark.seal", title: "Plan what to build",
                     detail: "Planning runs on this iPhone first, with Gemini in the cloud when it helps. Ginkgo only "
                         + "shows a plan that passes its checks for fit, strength and stability."),
        FirstRunPage(id: 3, symbol: "scissors", title: "Cut and assemble",
                     detail: "Lines in AR show where to cut, and a check scan confirms each piece. Then follow the "
                         + "3D steps with the screws and brackets Ginkgo picks."),
        FirstRunPage(id: 4, symbol: "tray.full", title: "No LiDAR? Try a sample",
                     detail: "Scanning needs an iPhone with LiDAR, such as an iPhone 12 Pro or later Pro model. "
                         + "Anyone can open My items and run the whole flow on a sample piece."),
    ]

    /// Shown once, on Home only (My items and Guide open with their own tab, and tests open screens directly).
    static func shouldShow(seen: Bool, initialTab: Int) -> Bool { !seen && initialTab == 0 }
}
