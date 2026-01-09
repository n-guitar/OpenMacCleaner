// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenMacCleaner",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "open-cleaner", targets: ["OpenCleanerCLI"]),
        .library(name: "OpenMacCleanerCore", targets: ["OpenMacCleanerCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Core library shared between GUI and CLI
        .target(
            name: "OpenMacCleanerCore",
            dependencies: [],
            path: "Sources/OpenMacCleanerCore",
            resources: [
                .process("Resources")
            ]
        ),
        
        // CLI Tool
        .executableTarget(
            name: "OpenCleanerCLI",
            dependencies: [
                "OpenMacCleanerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/OpenCleanerCLI",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        
        // Tests (run via xcodebuild, not swift test)
        // .testTarget(
        //     name: "OpenMacCleanerTests",
        //     dependencies: ["OpenMacCleanerCore"],
        //     path: "Tests/OpenMacCleanerTests"
        // ),
    ]
)
