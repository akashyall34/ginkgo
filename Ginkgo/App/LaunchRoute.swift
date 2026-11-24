/// Which screen the app opens on. Normally Home; tests pass `-openScreen <name>` (for example `scan` or
/// `my-items`) so they reach a screen directly, without depending on the taps that lead there.
enum LaunchRoute: String, CaseIterable, Equatable {
    case home
    case scan
    /// The flat-panel scan: thickness as well as size.
    case panel
    case example
    case transform
    case contrast
    case demo
    case parts
    case myItems = "my-items"
    case guide
    case settings
    case ideas
    case planning
    case verify
    /// Marking the cuts, on the sample bench.
    case cuts
    /// Checking the cut pieces, on the sample bench.
    case cutCheck = "cut-check"
    /// Step-by-step assembly, on the sample bench.
    case assembly
    case recordedRun = "recorded-run"
    case walkAround = "walk-around"

    init(arguments: [String]) {
        guard let flag = arguments.firstIndex(of: "-openScreen"), flag + 1 < arguments.count,
              let route = LaunchRoute(rawValue: arguments[flag + 1]) else {
            self = .home
            return
        }
        self = route
    }
}
