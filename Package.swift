// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "Embassy",
    products: [.library(name: "Embassy", targets: ["Embassy"])],
    targets: [.target(name: "Embassy", path: "./Sources"),
              .testTarget(name: "EmbassyTests", dependencies: ["Embassy"])]
)
