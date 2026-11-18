// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FreeMyMacOS",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FreeMyMacOSCore", targets: ["FreeMyMacOSCore"]),
        .executable(name: "FreeMyMacOS", targets: ["FreeMyMacOS"]),
    ],
    targets: [
        .target(name: "FreeMyMacOSCore"),
        .executableTarget(name: "FreeMyMacOS", dependencies: ["FreeMyMacOSCore"]),
        .testTarget(name: "FreeMyMacOSCoreTests", dependencies: ["FreeMyMacOSCore"]),
        .testTarget(name: "FreeMyMacOSTests", dependencies: ["FreeMyMacOS", "FreeMyMacOSCore"]),
    ],
    swiftLanguageModes: [.v6]
)
