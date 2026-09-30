// swift-tools-version: 6.0

import Foundation
import PackageDescription

let package = Package(
    name: "swift-osc-io-cocoa",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        .library(name: "SwiftOSCIO", targets: ["SwiftOSCIO"])
    ],
    dependencies: [
        .package(url: "https://github.com/orchetect/swift-osc-core", from: "1.4.0"),
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.0.0")

        // testing-only dependencies:
        // .package(url: "https://github.com/apple/swift-numerics", from: "1.1.1"),
        // .package(url: "https://github.com/orchetect/swift-testing-extensions", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "SwiftOSCIO",
            dependencies: [
                .product(name: "SwiftOSCCore", package: "swift-osc-core"),
                .product(name: "SwiftOSCIOCore", package: "swift-osc-core"),
                .product(name: "SwiftOSCIOInternals", package: "swift-osc-core"),
                .product(
                    name: "CocoaAsyncSocket",
                    package: "CocoaAsyncSocket",
                    condition: .when(platforms: [.macOS, .macCatalyst, .iOS, .tvOS, .visionOS, .driverKit])
                )
            ],
            swiftSettings: [.define("DEBUG", .when(configuration: .debug))]
        ),
        .testTarget(
            name: "SwiftOSCIOTests",
            dependencies: [
                "SwiftOSCIO"
                // .product(name: "Numerics", package: "swift-numerics"),
                // .product(name: "TestingExtensions", package: "swift-testing-extensions")
            ]
        )
    ]
)

// MARK: - Utilities

func hasEnvironmentVariable(_ name: String) -> Bool {
    ProcessInfo.processInfo.environment[name] != nil
}

// MARK: - CI Pipeline

if hasEnvironmentVariable("GITHUB_ACTIONS") {
    for target in package.targets.filter(\.isTest) {
        if target.swiftSettings == nil { target.swiftSettings = [] }
        target.swiftSettings? += [.define("GITHUB_ACTIONS", .when(configuration: .debug))]
    }
}
