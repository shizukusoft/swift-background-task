// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-background-task",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14),
        .tvOS(.v14),
        .watchOS(.v7),
        .macCatalyst(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BackgroundTask",
            targets: ["BackgroundTask"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/sinoru/swift-unified-log.git", from: "2.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BackgroundTask",
            dependencies: [
                .product(name: "UnifiedLogging", package: "swift-unified-log")
            ]),
        .testTarget(
            name: "BackgroundTaskTests",
            dependencies: ["BackgroundTask"]),
    ]
)
