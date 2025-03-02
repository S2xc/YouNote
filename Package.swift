// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "YouNote",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "YouNote",
            targets: ["YouNote"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "YouNote",
            dependencies: [],
            path: ".",
            sources: ["YouNote"])
    ]
)
