// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GinkgoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GinkgoCore", targets: ["GinkgoCore"]),
        .executable(name: "ginkgo-live", targets: ["GinkgoLive"]),
    ],
    targets: [
        .target(name: "GinkgoCore"),
        .executableTarget(name: "GinkgoLive", dependencies: ["GinkgoCore"]),
        .testTarget(name: "GinkgoCoreTests", dependencies: ["GinkgoCore"]),
    ]
)
