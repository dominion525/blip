// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Blip",
    platforms: [.macOS(.v13)],
    targets: [
        // AppKit-free logic, covered by tests
        .target(name: "BlipCore"),
        // The menu bar app itself
        .executableTarget(name: "Blip", dependencies: ["BlipCore"]),
        .testTarget(name: "BlipCoreTests", dependencies: ["BlipCore"]),
    ]
)
