// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MKit",
            targets: ["MKit"]),
        .library(
            name: "MSecurity",
            targets: ["MSecurity"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-certificates.git", .upToNextMajor(from: "1.7.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "MKit",
            dependencies: [
                .product(name: "X509", package: "swift-certificates")
            ]
        ),
        .target(
            name: "MSecurity",
            dependencies: [],
            path: "Sources/MSecurity"
        ),
        .testTarget(
            name: "MKitTests",
            dependencies: ["MKit"]),
    ]
)
