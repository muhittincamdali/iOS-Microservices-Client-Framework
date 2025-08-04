// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iOSMicroservicesClientFramework",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MicroservicesClient",
            targets: ["MicroservicesClient"]),
        .library(
            name: "MicroservicesClientCore",
            targets: ["MicroservicesClientCore"]),
        .library(
            name: "MicroservicesClientAnalytics",
            targets: ["MicroservicesClientAnalytics"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MicroservicesClient",
            dependencies: [
                "MicroservicesClientCore",
                "MicroservicesClientAnalytics",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/Microservices"),
        .target(
            name: "MicroservicesClientCore",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Core"),
        .target(
            name: "MicroservicesClientAnalytics",
            dependencies: [
                "MicroservicesClientCore",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Analytics"),
        .testTarget(
            name: "MicroservicesClientTests",
            dependencies: [
                "MicroservicesClient",
                "MicroservicesClientCore",
                "MicroservicesClientAnalytics"
            ],
            path: "Tests/MicroservicesClientTests"),
        .testTarget(
            name: "MicroservicesClientCoreTests",
            dependencies: ["MicroservicesClientCore"],
            path: "Tests/MicroservicesClientCoreTests"),
        .testTarget(
            name: "MicroservicesClientAnalyticsTests",
            dependencies: ["MicroservicesClientAnalytics"],
            path: "Tests/MicroservicesClientAnalyticsTests"),
        .testTarget(
            name: "MicroservicesClientPerformanceTests",
            dependencies: ["MicroservicesClient"],
            path: "Tests/MicroservicesClientPerformanceTests"),
    ]
) 