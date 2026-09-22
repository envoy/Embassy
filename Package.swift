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
            path: "Tests/EmbassyTests",
            // The library builds in Swift 6 mode. The XCTest suite still captures test-case
            // state in @Sendable completion handlers all over; it moves to Swift 6 with the
            // Swift Testing migration.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
