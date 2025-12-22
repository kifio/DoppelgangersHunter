// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DoppelgangersHunter",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "DoppelgangersHunter-CLI",
            targets: ["DoppelgangersHunter-CLI"]
        ),
        .library(
            name: "DoppelgangersHunter",
            type: .static,
            targets: ["DoppelgangersHunter"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jaywcjlove/FileType.git", from: "2.0.1")
    ],
    targets: [
        .executableTarget(
            name: "DoppelgangersHunter-CLI",
            dependencies: [
                "DoppelgangersHunter",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/DoppelgangersHunter-CLI"
        ),
        .target(
            name: "DoppelgangersHunter",
            dependencies: [
                .product(name: "FileType", package: "FileType"),
            ],
            path: "Sources/DoppelgangersHunter"
        ),
        .testTarget(
            name: "DoppelgangersHunter_Tests",
            dependencies: ["DoppelgangersHunter"]
        ),
    ]
)
