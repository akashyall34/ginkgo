import FirebaseAppCheck
import FirebaseCore
import GinkgoCore
import SwiftUI

@main
struct GinkgoApp: App {
    init() {
        FirebaseSetup.configureIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            let route = LaunchRoute(arguments: ProcessInfo.processInfo.arguments)
            switch route {
            case .home:
                HomeView()
            case .scan:
                NavigationStack { ScanView(source: FrameSources.makeDefault()) }
            case .panel:
                NavigationStack { ScanView(flatPanelFrom: FrameSources.makeDefault()) }
            case .example:
                NavigationStack { ExampleProofView() }
            case .transform:
                NavigationStack { ExampleTransformView() }
            case .contrast:
                NavigationStack { ExampleContrastView() }
            case .demo:
                DemoView()
            case .parts:
                // A measured cabinet-sized box with no photo: the offline path, as on a site with no signal.
                NavigationStack {
                    PartsView(box: FittedBox(length: 0.6, width: 0.35, height: 0.7, baseCenter: .zero, yaw: 0,
                                             uncertainty: 0.01, pointCount: 4000), photo: nil)
                }
            case .myItems:
                HomeView(initialTab: 1)
            case .guide:
                HomeView(initialTab: 2)
            case .settings:
                AppearanceSettingsView()
            case .ideas, .planning, .verify, .cuts, .cutCheck, .assembly, .takeApart:
                SampleRouteView(route: route)
            case .recordedRun:
                NavigationStack { ExampleRecordedRunView() }
            case .walkAround:
                NavigationStack { WalkAroundView() }
            }
        }
    }
}

/// The sample furniture turning into the bench, or a designed state if it can't be loaded.
struct ExampleTransformView: View {
    var body: some View {
        if let scene = TransformLayout.example() {
            TransformView(scene: scene)
        } else {
            ContentUnavailableView("Example unavailable", systemImage: "cube",
                                   description: Text("The sample furniture couldn't be loaded."))
        }
    }
}

/// The sample furniture-to-bench plan, or a designed state if it can't be loaded.
struct ExampleProofView: View {
    var body: some View {
        if let example = ProofModel.example() {
            ProofView(model: example)
        } else {
            ContentUnavailableView("Example unavailable", systemImage: "doc.questionmark",
                                   description: Text("The sample plan couldn't be loaded."))
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

/// Screens that need a piece of furniture, opened on the sample nightstand (for tests and the screen audit).
struct SampleRouteView: View {
    let route: LaunchRoute

    var body: some View {
        if let inventory = ExampleRecordedRunView.sampleInventory(),
           let bench = RuleBasedPlanner.bench(inventory: inventory) {
            NavigationStack {
                switch route {
                case .ideas: IdeasView(inventory: inventory)
                case .verify: VerifyView(plan: bench.plan, inventory: inventory, result: bench.validation)
                case .cuts: CutGuideView(plan: bench.plan, result: bench.validation, inventory: inventory)
                case .cutCheck: CutCheckView(plan: bench.plan, result: bench.validation, inventory: inventory)
                case .assembly: AssemblyView(plan: bench.plan, inventory: inventory)
                case .takeApart: TakeApartView(inventory: inventory, photo: nil)
                default: PlanningView(inventory: inventory)
                }
            }
        } else {
            ContentUnavailableView("Example unavailable", systemImage: "doc.questionmark",
                                   description: Text("The sample furniture couldn't be loaded."))
        }
    }
}
