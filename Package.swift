// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DeepSeekCard",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DeepSeekCard",
            dependencies: ["DeepSeekCardCore"],
            path: "Sources/DeepSeekCard"
        ),
        .target(
            name: "DeepSeekCardCore",
            path: "Sources/DeepSeekCardCore"
        ),
        .testTarget(
            name: "DeepSeekCardCoreTests",
            dependencies: ["DeepSeekCardCore"],
            path: "Tests/DeepSeekCardCoreTests"
        ),
    ]
)
