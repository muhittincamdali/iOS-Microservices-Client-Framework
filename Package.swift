// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MicroservicesClient",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "MicroservicesClient",
            targets: ["MicroservicesClient"]
        ),
        .library(
            name: "ServiceDiscovery",
            targets: ["ServiceDiscovery"]
        ),
        .library(
            name: "LoadBalancing",
            targets: ["LoadBalancing"]
        ),
        .library(
            name: "CircuitBreaker",
            targets: ["CircuitBreaker"]
        ),
        .library(
            name: "HealthMonitoring",
            targets: ["HealthMonitoring"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MicroservicesClient",
            dependencies: [
                "ServiceDiscovery",
                "LoadBalancing", 
                "CircuitBreaker",
                "HealthMonitoring",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "Sources/MicroservicesClient"
        ),
        .target(
            name: "ServiceDiscovery",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/ServiceDiscovery"
        ),
        .target(
            name: "LoadBalancing",
            dependencies: [
                "ServiceDiscovery",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/LoadBalancing"
        ),
        .target(
            name: "CircuitBreaker",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/CircuitBreaker"
        ),
        .target(
            name: "HealthMonitoring",
            dependencies: [
                "ServiceDiscovery",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/HealthMonitoring"
        ),
        .testTarget(
            name: "MicroservicesClientTests",
            dependencies: [
                "MicroservicesClient",
                "ServiceDiscovery",
                "LoadBalancing",
                "CircuitBreaker",
                "HealthMonitoring"
            ],
            path: "Tests"
        )
    ]
) 