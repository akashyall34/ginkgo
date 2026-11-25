import FirebaseCore
import FirebaseRemoteConfig
import Foundation
import GinkgoCore

/// Firebase glue for `RemoteSettings`: fetch, then hand the raw values to the checked `apply`.
enum RemoteConfigLoader {
    /// Fetches and applies Remote Config. With no Firebase, no network or no values, the built-in ones stay.
    static func load() async {
        guard FirebaseApp.app() != nil else { return }
        let config = RemoteConfig.remoteConfig()
        guard (try? await config.fetchAndActivate()) != nil else { return }
        let text = config.configValue(forKey: RemoteSettings.modelsKey)
        var numbers: [String: Double?] = [:]
        for key in ValidatorSettings.Key.allCases {
            let value = config.configValue(forKey: key.rawValue)
            numbers[key.rawValue] = value.source == .remote ? Double(value.stringValue) : nil
        }
        RemoteSettings.apply(models: text.source == .remote ? text.stringValue : nil, numbers: numbers)
    }
}
