// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DeliciousCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DeliciousCore", targets: ["DeliciousCore"]),
    ],
    targets: [
        .target(name: "DeliciousCore"),
        .testTarget(name: "DeliciousCoreTests", dependencies: ["DeliciousCore"]),
    ]
)
