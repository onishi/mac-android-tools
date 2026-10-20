// swift-tools-version: 5.10

import PackageDescription

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
        .executableTarget(name: "AndroidTablet", dependencies: ["AndroidToolsCore"]),
        .executableTarget(name: "AndroidJapaneseSwitch", dependencies: ["AndroidToolsCore"]),
        .executableTarget(name: "SendClipboardImage", dependencies: ["AndroidToolsCore"]),
        .testTarget(name: "AndroidToolsCoreTests", dependencies: ["AndroidToolsCore"]),
    ]
)
