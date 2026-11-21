/// Which screen the app opens on. Normally Home; tests pass `-openScreen scan` or
/// `-openScreen example` so they reach a screen without depending on Home's design.
enum LaunchRoute: Equatable {
    case home
    case scan
    case example
    case transform
    case contrast
    case demo

    init(arguments: [String]) {
        guard let flag = arguments.firstIndex(of: "-openScreen"), flag + 1 < arguments.count else {
            self = .home
            return
        }
        switch arguments[flag + 1] {
        case "scan": self = .scan
        case "example": self = .example
        case "transform": self = .transform
        case "contrast": self = .contrast
        case "demo": self = .demo
        default: self = .home
        }
    }
}
