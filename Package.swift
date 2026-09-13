// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Saga",
    platforms: [.iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Saga",
            targets: ["Saga"]
        ),
        .library(
            name: "SagaFlow",
            targets: ["SagaFlow"]
        ),
        .library(
            name: "SagaSheets",
            targets: ["SagaSheets"]
        ),
        .library(
            name: "SagaUpdates",
            targets: ["SagaUpdates"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Saga"
        ),
        .target(
            name: "SagaFlow"
        ),
        .target(
            name: "SagaSheets"
        ),
        .target(
            name: "SagaUpdates"
        ),
        .testTarget(
            name: "SagaTests",
            dependencies: ["Saga"]
        ),
        .testTarget(
            name: "SagaUpdatesTests",
            dependencies: ["SagaUpdates"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
