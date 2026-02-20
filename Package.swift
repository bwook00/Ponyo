// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ponyo",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Ponyo",
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PonyoTests",
            dependencies: ["Ponyo"],
            path: "Tests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
