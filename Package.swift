// swift-tools-version: 6.2

import PackageDescription

// AppKit apps: run UI code on the main actor by default.
let appSettings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "mac-android-tools",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AndroidTablet", targets: ["AndroidTablet"]),
        .executable(name: "AndroidJapaneseSwitch", targets: ["AndroidJapaneseSwitch"]),
        .executable(name: "SendClipboardImage", targets: ["SendClipboardImage"]),
    ],
    targets: [
        .target(name: "AndroidToolsCore"),
        .executableTarget(
            name: "AndroidTablet",
            dependencies: ["AndroidToolsCore"],
            swiftSettings: appSettings
        ),
        .executableTarget(
            name: "AndroidJapaneseSwitch",
            dependencies: ["AndroidToolsCore"],
            swiftSettings: appSettings
        ),
        .executableTarget(
            name: "SendClipboardImage",
            dependencies: ["AndroidToolsCore"],
            swiftSettings: appSettings
        ),
        .testTarget(name: "AndroidToolsCoreTests", dependencies: ["AndroidToolsCore"]),
    ]
)
