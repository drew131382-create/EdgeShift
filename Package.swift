// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EdgeShift",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "EdgeShift", targets: ["EdgeShift"])],
    targets: [
        .executableTarget(name: "EdgeShift"),
        .testTarget(name: "EdgeShiftTests", dependencies: ["EdgeShift"])
    ]
)
