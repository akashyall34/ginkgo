import Foundation

/// What each material allows. Ginkgo only plans cuts in solid wood and plywood; everything else is reused whole.
public extension Material {
    /// Whether Ginkgo's plans may cut this material. A whole-part reuse is always allowed.
    var canBeCut: Bool {
        switch self {
        case .solidWood, .plywood: return true
        case .particleboardMDF, .plastic, .cardboard: return false
        }
    }

    /// The name people read, for example "particleboard/MDF".
    var displayName: String {
        switch self {
        case .solidWood: return "solid wood"
        case .plywood: return "plywood"
        case .particleboardMDF: return "particleboard/MDF"
        case .plastic: return "plastic"
        case .cardboard: return "cardboard"
        }
    }

    /// Why a material can't be cut, finishing the sentence "<part> is <material>, which ...".
    var whyNotCut: String {
        switch self {
        case .solidWood, .plywood: return "can be cut"
        case .particleboardMDF: return "crumbles when cut"
        case .plastic: return "has thin walls that crack or warp when sawn"
        case .cardboard: return "is too weak to cut into furniture parts"
        }
    }
}
