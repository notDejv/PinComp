// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PinCompKit",
    platforms: [.iOS("27.0")],
    products: [
        .library(name: "PinCompCore", targets: ["PinCompCore"]),
        .library(name: "PinCompUI", targets: ["PinCompUI"]),
        .library(name: "PinCompActivity", targets: ["PinCompActivity"]),
    ],
    targets: [
        .target(name: "PinCompCore"),
        .target(name: "PinCompUI", dependencies: ["PinCompCore"]),
        .target(name: "PinCompActivity", dependencies: ["PinCompCore"]),
        .testTarget(name: "PinCompCoreTests", dependencies: ["PinCompCore"]),
    ],
    swiftLanguageModes: [.v6]
)
