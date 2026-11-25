import Foundation

/// The AI tasks Ginkgo routes between the phone and the cloud.
public enum AITask: String, Sendable, Codable, CaseIterable {
    /// Propose a plan from measured numbers and a parts list (text only).
    case planFromNumbers = "plan_from_numbers"
    /// Read the furniture photo into a parts list (needs image input).
    case readPhoto = "read_photo"
    /// Replan a plan made on the phone or by the rules, in the cloud, once the network is back.
    case improvePlan = "improve_plan"
}

/// Where a task runs.
public enum Venue: String, Sendable, Codable, CaseIterable {
    /// Apple's Foundation Models, on this iPhone.
    case device
    /// Gemini, through Firebase AI Logic.
    case cloud
    /// Tested Swift code on the phone, no model: the rule-based planner or the LiDAR parts template.
    case code
}

/// Why a task went where it did. `message` is what the screen shows.
public enum RouteReason: String, Sendable, Codable, CaseIterable {
    case numbersOnDevice = "numbers_on_device"
    case needsPhoto = "needs_photo"
    case deviceFailedValidator = "device_failed_validator"
    /// The on-device model stopped or errored before the validator rejected it enough times to give up.
    case deviceDidNotFinish = "device_did_not_finish"
    case deviceUnavailable = "device_unavailable"
    case offlineNoDeviceModel = "offline_no_device_model"
    case offlineDeviceFailed = "offline_device_failed"
    case offlinePhotoTemplate = "offline_photo_template"
    case improvedInCloud = "improved_in_cloud"
    case offlineKeepPlan = "offline_keep_plan"

    public var message: String {
        switch self {
        case .numbersOnDevice: return "Planned on this iPhone"
        case .needsPhoto: return "Sent to Gemini: needs the photo"
        case .deviceFailedValidator:
            return "Sent to Gemini: the on-device plan failed the validator \(HybridRouter.deviceAttempts) times"
        case .deviceUnavailable: return "Sent to Gemini: the on-device model isn't available"
        case .deviceDidNotFinish: return "Sent to Gemini: the on-device model didn't finish a plan in time"
        case .offlineNoDeviceModel: return "No network and no on-device model: rule-based plan"
        case .offlineDeviceFailed: return "No network, and the on-device plans failed the validator: rule-based plan"
        case .offlinePhotoTemplate: return "No network: parts from the LiDAR faces"
        case .improvedInCloud: return "Improved by Gemini in the cloud"
        case .offlineKeepPlan: return "No network: keeping this plan"
        }
    }
}

/// What the phone can do right now.
public struct RouteConditions: Sendable, Equatable {
    public var deviceModelAvailable: Bool
    public var online: Bool
    /// On-device plans for this piece that the validator rejected so far.
    public var deviceRejections: Int
    /// The on-device model already ran and ended without an accepted plan, for any reason.
    public var deviceFinishedWithoutPlan: Bool

    public init(deviceModelAvailable: Bool, online: Bool, deviceRejections: Int = 0, deviceFinishedWithoutPlan: Bool = false) {
        self.deviceModelAvailable = deviceModelAvailable
        self.online = online
        self.deviceRejections = deviceRejections
        self.deviceFinishedWithoutPlan = deviceFinishedWithoutPlan
    }
}

public struct Route: Sendable, Equatable {
    public var venue: Venue
    public var reason: RouteReason

    public init(venue: Venue, reason: RouteReason) {
        self.venue = venue
        self.reason = reason
    }
}

/// Routes each task by what it needs, not only by what's available:
/// numbers go to the phone; the photo goes to the cloud (the on-device model takes no images);
/// after `deviceAttempts` validator rejections on the phone, planning goes to the cloud.
/// With no network, tested code covers whatever the phone's model can't.
public enum HybridRouter {
    /// On-device plans the validator may reject before planning moves to the cloud.
    public static let deviceAttempts = 3

    public static func route(_ task: AITask, _ conditions: RouteConditions) -> Route {
        switch task {
        case .readPhoto:
            return conditions.online
                ? Route(venue: .cloud, reason: .needsPhoto)
                : Route(venue: .code, reason: .offlinePhotoTemplate)
        case .improvePlan:
            return conditions.online
                ? Route(venue: .cloud, reason: .improvedInCloud)
                : Route(venue: .code, reason: .offlineKeepPlan)
        case .planFromNumbers:
            let rejectedEnough = conditions.deviceRejections >= deviceAttempts
            let deviceSpent = rejectedEnough || conditions.deviceFinishedWithoutPlan
            if conditions.deviceModelAvailable && !deviceSpent {
                return Route(venue: .device, reason: .numbersOnDevice)
            }
            if conditions.online {
                let why: RouteReason = rejectedEnough ? .deviceFailedValidator
                    : deviceSpent ? .deviceDidNotFinish : .deviceUnavailable
                return Route(venue: .cloud, reason: why)
            }
            return Route(venue: .code, reason: deviceSpent ? .offlineDeviceFailed : .offlineNoDeviceModel)
        }
    }
}
