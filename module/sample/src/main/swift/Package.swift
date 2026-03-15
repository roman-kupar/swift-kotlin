// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestModule",
    products: [
        .library(name: "TestModule", type: .dynamic, targets: ["TestModule"])
    ],
    targets: [
        .target(name: "TestModule")
    ]
)