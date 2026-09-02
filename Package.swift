// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Blip",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Hotkey recorder UI and registration. Uses Carbon RegisterEventHotKey underneath, so no accessibility permission is needed
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.0.0"),
    ],
    targets: [
        // AppKit-free logic, covered by tests
        .target(name: "BlipCore"),
        // The menu bar app itself
        .executableTarget(
            name: "Blip",
            dependencies: [
                "BlipCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "BlipCoreTests", dependencies: ["BlipCore"]),
    ]
)
