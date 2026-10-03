// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DeepPeak",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DeepPeak",
            dependencies: ["DeepPeakCore"],
            path: "Sources/DeepPeak"
        ),
        .target(
            name: "DeepPeakCore",
            path: "Sources/DeepPeakCore"
        ),
        .testTarget(
            name: "DeepPeakCoreTests",
            dependencies: ["DeepPeakCore"],
            path: "Tests/DeepPeakCoreTests"
        ),
    ]
)
