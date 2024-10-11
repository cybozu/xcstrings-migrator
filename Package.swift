// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "xcstrings-migrator",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "xcstrings-migrator",
            targets: ["xcstrings-migrator"]
        ),
        .library(
            name: "XCStringsMigrator",
            targets: ["XCStringsMigrator"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            exact: "1.5.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "xcstrings-migrator",
            dependencies: [
                .target(name: "XCStringsMigrator"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "XCStringsMigrator",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
            ]
        ),
        .testTarget(
            name: "XCStringsMigratorTests",
            dependencies: [
                .target(name: "XCStringsMigrator"),
            ],
            resources: [
                .copy("Resources/Migrator"),
                .copy("Resources/Reverter"),
            ]
        ),
    ]
)
