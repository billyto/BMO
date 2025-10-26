// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BMO",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BMO", targets: ["BMO"]),
        .library(name: "BMOLib", targets: ["BMOLib"])
    ],
    targets: [
        // Library target with SwiftUI views - supports previews
        .target(
            name: "BMOLib",
            dependencies: [],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        // Executable target - depends on library
        .executableTarget(
            name: "BMO",
            dependencies: ["BMOLib"],
            swiftSettings: [
                .define("ENABLE_DEBUG_DYLIB", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "BMOTests",
            dependencies: ["BMO"]
        ),
    ]
)
