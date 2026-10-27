// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GlossaCapture",
    // NFR6: macOS 13 or later. (The package still builds elsewhere for tests;
    // the macOS-only parts are wrapped in #if os(macOS).)
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GlossaCapture",
            targets: ["GlossaCapture"]
        ),
        .executable(
            name: "CaptureDemo",
            targets: ["CaptureDemo"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GlossaCapture",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .executableTarget(
            name: "CaptureDemo",
            dependencies: ["GlossaCapture"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "GlossaCaptureTests",
            dependencies: ["GlossaCapture"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
