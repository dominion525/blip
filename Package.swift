// swift-tools-version: 5.9

import PackageDescription

// Only the AppKit-free logic lives in this package. The app itself (Sources/Blip) and BlipTests are
// Xcode targets defined in project.yml (XcodeGen), and they depend on this package.
let package = Package(
    name: "BlipCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BlipCore", targets: ["BlipCore"]),
    ],
    targets: [
        .target(name: "BlipCore"),
        .testTarget(name: "BlipCoreTests", dependencies: ["BlipCore"]),
    ]
)
