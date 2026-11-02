// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "GlossaIntegration",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GlossaIntegration",
            targets: ["GlossaIntegration"]
        ),
    ],
    dependencies: [
        .package(path: "../GlossaCapture"),
        .package(path: "../GlossaTranslation")
    ],
    
    targets: [
        .target(
            name: "GlossaIntegration",
            dependencies: [
                .product(
                    name: "GlossaCapture",
                    package: "GlossaCapture"
                ),
                .product(
                    name: "GlossaTranslation",
                    package: "GlossaTranslation"
                ),
            ],
        ),
        .testTarget(
            name: "GlossaIntegrationTests",
            dependencies: [
                "GlossaIntegration",
                .product(
                    name: "GlossaCapture",
                    package: "GlossaCapture"
                ),
                .product(
                    name: "GlossaTranslation",
                    package: "GlossaTranslation"
                ),
            ],
        ),
    ]
)