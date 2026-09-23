// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Embassy",
    products: [
        .library(
            name: "Embassy",
            targets: ["Embassy"])
    ],
    targets: [
        .target(
            name: "Embassy",
            path: "./Sources",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "EmbassyTests",
            dependencies: ["Embassy"],
            exclude: ["Info.plist"]
        )
    ]
)
