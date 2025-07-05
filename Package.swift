// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YAML",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macCatalyst(.v16),
        .visionOS(.v1),
        .custom("Linux", versionString: "0.0.0"),
        .custom("Windows", versionString: "0.0.0"),
        .custom("Android", versionString: "0.0.0")
    ],
    products: [
        .library(
            name: "YAML",
            targets: ["YAML"]),
    ],
    targets: [
        .target(
            name: "YAML",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
                .define("SWIFT_PACKAGE"),
                .unsafeFlags(["-enable-experimental-feature", "Embedded"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "YAMLTests",
            dependencies: ["YAML"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
