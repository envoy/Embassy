// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Embassy",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "Embassy", targets: ["Embassy"])
    ],
    targets: [
        .target(name: "Embassy", path: "./Sources"),
        .testTarget(name: "EmbassyTests", dependencies: ["Embassy"], path: "./Tests/EmbassyTests")
    ]
)
