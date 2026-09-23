// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Embassy",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "Embassy",
            targets: ["Embassy"]
        )
    ],
    targets: [
        .target(
            name: "Embassy",
            path: "Sources"
        ),
        .testTarget(
            name: "EmbassyTests",
            dependencies: ["Embassy"],
            path: "Tests/EmbassyTests"
        )
    ]
)
