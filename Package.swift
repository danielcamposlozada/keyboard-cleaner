// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "keyboard-cleaner",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "keylock", targets: ["keylock"]),
        .executable(name: "KeyboardCleaner", targets: ["KeyboardCleaner"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.7.0"
        ),
    ],
    targets: [
        .target(name: "KeylockCore", swiftSettings: v5),
        .executableTarget(
            name: "keylock",
            dependencies: [
                "KeylockCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: v5
        ),
        .executableTarget(
            name: "KeyboardCleaner",
            dependencies: ["KeylockCore"],
            swiftSettings: v5
        ),
    ]
)
