// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Embassy",
     platforms: [
        .iOS(.v11),
    ],
    products: [.library(name: "Embassy", targets: ["Embassy"])],
    targets: [.target(name: "Embassy", path: "./Sources")]
)
