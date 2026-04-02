// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeepGoing",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "KeepGoingCore",
            path: "Sources/KeepGoingCore"
        ),
        .executableTarget(
            name: "KeepGoing",
            dependencies: ["KeepGoingCore"],
            path: "Sources/KeepGoing"
        ),
        .executableTarget(
            name: "keepgoing-cli",
            dependencies: ["KeepGoingCore"],
            path: "Sources/keepgoing-cli"
        ),
        .testTarget(
            name: "KeepGoingTests",
            dependencies: ["KeepGoingCore"],
            path: "Tests/KeepGoingTests"
        ),
    ]
)
