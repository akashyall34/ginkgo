import FirebaseAppCheck
import FirebaseCore
import SwiftUI

@main
struct GinkgoApp: App {
    init() {
        FirebaseSetup.configureIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

enum FirebaseSetup {
    /// True once GoogleService-Info.plist is bundled with the app.
    static var isConfigFilePresent: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    /// Configures Firebase when its config file is present. Without it the app still
    /// runs; AI features show their designed "unavailable" state instead of crashing.
    static func configureIfAvailable() {
        guard isConfigFilePresent, FirebaseApp.app() == nil else { return }
        AppCheck.setAppCheckProviderFactory(appCheckProviderFactory())
        FirebaseApp.configure()
    }

    /// The simulator can't use Apple's DeviceCheck, so it uses App Check's debug
    /// provider with a debug token registered in the Firebase console. Real devices
    /// use DeviceCheck, so the same build keeps working if enforcement is turned on.
    static func appCheckProviderFactory() -> AppCheckProviderFactory {
        #if targetEnvironment(simulator)
        return AppCheckDebugProviderFactory()
        #else
        return DeviceCheckProviderFactory()
        #endif
    }
}
