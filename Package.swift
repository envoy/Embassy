// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Embassy",
    products: [.library(name: "Embassy", targets: ["Embassy"])],
    targets: [.target(name: "Embassy", path: "./Sources")]
)
