// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TranslatorBuddy",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "TranslatorBuddy", targets: ["TranslatorBuddy"]),
        .library(name: "TranslatorBuddyCore", targets: ["TranslatorBuddyCore"])
    ],
    targets: [
        .target(name: "TranslatorBuddyCore"),
        .executableTarget(
            name: "TranslatorBuddy",
            dependencies: ["TranslatorBuddyCore"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Translation")
            ]
        ),
        .testTarget(
            name: "TranslatorBuddyCoreTests",
            dependencies: ["TranslatorBuddyCore"]
        )
    ]
)
